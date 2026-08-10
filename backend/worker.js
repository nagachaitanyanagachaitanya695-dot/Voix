/**
 * Voix backend — a Cloudflare Worker.
 *
 * Its entire job is to hold the OpenAI API key so the app never has to. An
 * APK is a zip file: a key shipped inside one is a key published. This Worker
 * keeps the key server-side and hands the app only short-lived credentials
 * that expire in about a minute.
 *
 * Two endpoints:
 *   POST /v1/session  → an ephemeral token for the live voice-to-voice mode
 *   POST /v1/chat     → the text tutor (corrections, scores, replies)
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
    // The single most important thing in this file. Live voice costs real
    // money per minute, and without a cap one person (or one bug that
    // reconnects in a loop) can run up a bill overnight.
    const deviceId = request.headers.get('x-voix-device') ?? 'unknown';
    const budget = await checkBudget(env, deviceId, url.pathname);
    if (!budget.ok) {
      return json({ error: budget.message, code: 'budget_exceeded' }, 429, origin);
    }

    try {
      switch (url.pathname) {
        case '/v1/session':
          return await mintRealtimeToken(request, env, origin);
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

/**
 * Mints an ephemeral Realtime credential.
 *
 * The returned `ek_...` value is what the app opens its WebSocket with. It
 * expires in about a minute, so a stolen one is worth almost nothing — which
 * is the entire reason the app is never given the real key.
 */
async function mintRealtimeToken(request, env, origin) {
  const body = await safeJson(request);

  const response = await fetch(`${OPENAI}/realtime/client_secrets`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      // Ties the token to one learner, so OpenAI's abuse tooling can act on a
      // single account rather than on your whole project.
      ...(body.userId ? { 'safety_identifier': String(body.userId) } : {}),
      expires_after: { anchor: 'created_at', seconds: 60 },
      session: {
        type: 'realtime',
        // Configured server-side on purpose: you can change the model or the
        // teaching instructions without shipping an app update, and the app
        // cannot ask for a more expensive model than you allow.
        model: env.REALTIME_MODEL,
        instructions: tutorInstructions(body),
        audio: {
          input: {
            format: { type: 'audio/pcm', rate: 24000 },
            transcription: { model: env.TRANSCRIBE_MODEL ?? 'whisper-1' },
            turn_detection: { type: 'server_vad', silence_duration_ms: 700 },
          },
          output: {
            format: { type: 'audio/pcm', rate: 24000 },
            voice: body.voice === 'female' ? 'shimmer' : 'verse',
            // Slightly under natural pace: this is a language tutor, and a
            // learner cannot follow a native-speed reply.
            speed: 0.95,
          },
        },
      },
    }),
  });

  if (!response.ok) {
    console.error('client_secrets failed', response.status, await response.text());
    return json({ error: 'Could not start a voice session.' }, 502, origin);
  }

  const data = await response.json();
  // Only the token and the model go back to the app. Nothing else.
  return json(
    { token: data.value, expiresAt: data.expires_at, model: env.REALTIME_MODEL },
    200,
    origin,
  );
}

/** The text tutor, used by the non-voice path and for end-of-session reports. */
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
async function checkBudget(env, deviceId, pathname) {
  if (!env.VOIX_KV) return { ok: true };

  // Voice is the expensive one, so it gets its own, much tighter cap.
  const isVoice = pathname === '/v1/session';
  const limit = Number(isVoice ? env.DAILY_VOICE_LIMIT ?? 12 : env.DAILY_CHAT_LIMIT ?? 300);
  const day = new Date().toISOString().slice(0, 10);
  const key = `${isVoice ? 'v' : 'c'}:${day}:${deviceId}`;

  const used = Number((await env.VOIX_KV.get(key)) ?? 0);
  if (used >= limit) {
    return {
      ok: false,
      message: isVoice
        ? 'You have reached today\'s limit for live voice practice. It resets tomorrow.'
        : 'You have reached today\'s practice limit. It resets tomorrow.',
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
