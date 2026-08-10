/**
 * Voix backend — a Cloudflare Worker.
 *
 * Its entire job is to hold the OpenAI API key so the app never has to. An
 * APK is a zip file: a key shipped inside one is a key published. This Worker
 * keeps the key server-side and the app only ever talks to this Worker.
 *
 * One endpoint:
 *   POST /v1/chat  → the tutor's reply, corrections and end-of-session scores
 *
 * The learner's speech is handled by the phone itself — Android's own
 * recogniser turns it into text, and the phone's text-to-speech reads the
 * reply back. Neither costs anything, so audio never reaches this Worker.
 *
 * Deploy instructions: backend/README.md
 */

// The app sends this so strangers who find the URL cannot spend your money.
// Not a strong secret — it ships in the APK — but it stops casual abuse.
// Real protection is the per-device budget below.
const APP_TOKEN_HEADER = 'x-voix-app-token';

const OPENAI = 'https://api.openai.com/v1';

export default {
  async fetch(request, env, ctx) {
    const origin = request.headers.get('Origin') ?? '*';

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(origin) });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Use POST.' }, 405, origin);
    }
    if (!env.OPENAI_API_KEY) {
      return json({ error: 'Server is not configured.' }, 500, origin);
    }

    // ── Auth ───────────────────────────────────────────────────────────
    if (env.APP_TOKEN && request.headers.get(APP_TOKEN_HEADER) !== env.APP_TOKEN) {
      return json({ error: 'Not authorised.' }, 401, origin);
    }

    const url = new URL(request.url);

    // ── Budget ─────────────────────────────────────────────────────────
    // Without a cap, one person — or one retry loop in a bad build — can run
    // up a bill overnight on your card.
    const deviceId = request.headers.get('x-voix-device') ?? 'unknown';
    const budget = await checkBudget(env, deviceId);
    if (!budget.ok) {
      return json({ error: budget.message, code: 'budget_exceeded' }, 429, origin);
    }

    try {
      switch (url.pathname) {
        case '/v1/chat':
          return await chat(request, env, origin);
        default:
          return json({ error: 'Unknown endpoint.' }, 404, origin);
      }
    } catch (err) {
      // Never leak the upstream error text to the app — it can contain
      // request details and, in some failure modes, key fragments.
      console.error('voix-backend', err?.stack ?? String(err));
      return json({ error: 'Upstream request failed.' }, 502, origin);
    }
  },
};

/** The tutor: one reply, or one end-of-session report. */
async function chat(request, env, origin) {
  const body = await safeJson(request);

  const response = await fetch(`${OPENAI}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: env.CHAT_MODEL,
      messages: [
        { role: 'system', content: tutorInstructions(body) },
        ...(Array.isArray(body.messages) ? body.messages.slice(-20) : []),
      ],
      // Caps the bill per request. A tutor's turn is a few sentences; a model
      // that decides to write an essay is a bug you pay for.
      max_completion_tokens: 500,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    console.error('chat failed', response.status, await response.text());
    return json({ error: 'The tutor is unavailable right now.' }, 502, origin);
  }

  const data = await response.json();
  return json({ content: data.choices?.[0]?.message?.content ?? '' }, 200, origin);
}

/**
 * The teaching prompt.
 *
 * Lives on the server so it can be improved without an app release — prompt
 * wording is the thing you will tune most often.
 */
function tutorInstructions(body) {
  const level = ['beginner', 'intermediate', 'advanced'].includes(body.level)
    ? body.level
    : 'beginner';
  const native = String(body.nativeLanguage ?? 'Telugu').slice(0, 40);
  const scenario = String(body.scenario ?? 'everyday conversation').slice(0, 120);
  const genZ = body.mode === 'genZ';

  return [
    `You are Voix, a warm and encouraging English conversation tutor.`,
    `The learner's first language is ${native}. Their level is ${level}.`,
    `Today's scenario: ${scenario}.`,
    ``,
    `How to speak:`,
    `- Keep replies to 1-3 short sentences. This is a conversation, not a lecture.`,
    `- Match your vocabulary to a ${level} learner. Never show off with rare words.`,
    `- Always end with a question, so the learner has something to say back.`,
    genZ
      ? `- Use current casual/Gen-Z English, slang and internet phrasing naturally, and explain any slang you use in one short clause.`
      : `- Use clear, standard, everyday English.`,
    ``,
    `Correcting mistakes:`,
    `- Correct grammar and word choice gently, and only when it matters for being understood. Do not correct every small slip; that discourages people.`,
    `- Give the correction, then a one-line reason a ${level} learner would follow.`,
    `- You may explain a difficult point in ${native} if the learner seems stuck, then return to English.`,
    `- Never mock a mistake. Praise real progress specifically, not with empty phrases.`,
    ``,
    `If the learner asks a question in ${native}, or asks you to translate something, do it — helping them understand is the job.`,
  ].join('\n');
}

// ── Budget ────────────────────────────────────────────────────────────────

/**
 * A per-device daily cap, stored in Workers KV.
 *
 * If no KV namespace is bound the Worker still runs and simply does not
 * enforce a cap — so a first deploy works before you have set KV up. Bind it
 * before you tell anyone the app exists.
 */
async function checkBudget(env, deviceId) {
  if (!env.VOIX_KV) return { ok: true };

  const limit = Number(env.DAILY_CHAT_LIMIT ?? 300);
  const day = new Date().toISOString().slice(0, 10);
  const key = `c:${day}:${deviceId}`;

  const used = Number((await env.VOIX_KV.get(key)) ?? 0);
  if (used >= limit) {
    return {
      ok: false,
      message: 'You have reached today\'s practice limit. It resets tomorrow.',
    };
  }

  // Two days, so a request just before midnight cannot resurrect a stale count.
  await env.VOIX_KV.put(key, String(used + 1), { expirationTtl: 60 * 60 * 48 });
  return { ok: true };
}

// ── Helpers ───────────────────────────────────────────────────────────────

async function safeJson(request) {
  try {
    const parsed = await request.json();
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

function cors(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': `Content-Type, ${APP_TOKEN_HEADER}, x-voix-device`,
    'Access-Control-Max-Age': '86400',
  };
}

function json(body, status, origin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors(origin) },
  });
}
