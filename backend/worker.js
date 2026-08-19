/**
 * Voix backend — a Cloudflare Worker.
 *
 * Its entire job is to hold the API keys so the app never has to. An APK is a
 * zip file: a key shipped inside one is a key published. This Worker keeps the
 * keys server-side and the app only ever talks to this Worker.
 *
 * Endpoints:
 *   POST /v1/chat    → the tutor's reply, corrections and end-of-session scores
 *   POST /v1/verify  → checks a Play purchase token with Google, grants premium
 *   POST /v1/session → credentials for a live voice call, subscribers only
 *   POST /v1/word    → everything about one word: meaning, forms, history
 *
 * For everyone, speech is handled by the phone itself — Android's own
 * recogniser turns it into text and its text-to-speech reads the reply back.
 * That costs nothing. A live call streams audio in both directions and is
 * billed per minute, which is why it is the paid feature and why /v1/session
 * refuses anyone this Worker has not verified as a subscriber. The app also
 * hides it from non-subscribers, but that is a courtesy, not the control: an
 * APK can be edited, this Worker cannot.
 *
 * The live call can run on either of two providers, chosen by which secrets
 * you set — see `liveSession`. The app is told which one it got and speaks
 * that protocol; nothing else in the app changes.
 *
 * Deploy instructions: backend/README.md
 */

// The app sends this so strangers who find the URL cannot spend your money.
// Not a strong secret — it ships in the APK — but it stops casual abuse.
// Real protection is the per-device budget below.
const APP_TOKEN_HEADER = 'x-voix-app-token';

const OPENAI = 'https://api.openai.com/v1';
const ELEVENLABS = 'https://api.elevenlabs.io/v1';

export default {
  async fetch(request, env, ctx) {
    const origin = request.headers.get('Origin') ?? '*';

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(origin) });
    }
    if (request.method !== 'POST') {
      return json({ error: 'Use POST.' }, 405, origin);
    }
    // Not checked globally: a deploy that only has an ElevenLabs key can still
    // run live calls, and the app falls back to its own on-device tutor for
    // text. Each endpoint checks the key it actually needs.

    // ── Auth ───────────────────────────────────────────────────────────
    if (env.APP_TOKEN && request.headers.get(APP_TOKEN_HEADER) !== env.APP_TOKEN) {
      return json({ error: 'Not authorised.' }, 401, origin);
    }

    const url = new URL(request.url);

    // ── Budget ─────────────────────────────────────────────────────────
    // Without a cap, one person — or one retry loop in a bad build — can run
    // up a bill overnight on your card.
    const deviceId = request.headers.get('x-voix-device') ?? 'unknown';
    const budget = await checkBudget(env, deviceId, url.pathname);
    if (!budget.ok) {
      return json({ error: budget.message, code: 'budget_exceeded' }, 429, origin);
    }

    try {
      switch (url.pathname) {
        case '/v1/chat':
          return await chat(request, env, origin);
        case '/v1/verify':
          return await verifyPurchase(request, env, origin);
        case '/v1/session':
          return await liveSession(request, env, origin);
        case '/v1/word':
          return await explainWord(request, env, origin);
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
 * Checks a Play purchase token with Google and records the entitlement.
 *
 * The app tells us it bought something; Google tells us whether that is true.
 * Only Google's answer is stored.
 */
async function verifyPurchase(request, env, origin) {
  const body = await safeJson(request);
  const userId = String(body.userId ?? '').slice(0, 128);
  const purchaseToken = String(body.purchaseToken ?? '');

  if (!userId || !purchaseToken) {
    return json({ premium: false, error: 'Missing account or token.' }, 400, origin);
  }
  if (!env.PLAY_SERVICE_ACCOUNT_JSON || !env.ANDROID_PACKAGE_NAME) {
    console.error('verify: Play credentials not configured');
    return json({ premium: false, error: 'Server is not configured.' }, 500, origin);
  }

  const accessToken = await googleAccessToken(env);
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(env.ANDROID_PACKAGE_NAME)}/purchases/subscriptionsv2/` +
    `tokens/${encodeURIComponent(purchaseToken)}`;

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    // A 404 here is the normal answer for a token that was never real, so this
    // is not necessarily an outage.
    console.error('verify: Google said', response.status, await response.text());
    return json({ premium: false }, 200, origin);
  }

  const subscription = await response.json();

  // ACTIVE covers a paid subscription; IN_GRACE_PERIOD is someone whose
  // payment failed but whose access Google expects us to keep for now.
  // Cancelling does not end access — subscriptionState stays ACTIVE until the
  // paid period actually runs out, which is what expiryTime tells us.
  const activeStates = ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'];
  const expiryTime = subscription?.lineItems?.[0]?.expiryTime;
  const expiresAt = expiryTime ? Date.parse(expiryTime) : 0;

  const premium =
    activeStates.includes(subscription?.subscriptionState) && expiresAt > Date.now();

  if (premium) {
    await grantPremium(env, userId, expiresAt);
  }

  return json({ premium, expiresAt: premium ? expiresAt : null }, 200, origin);
}

/**
 * Mints an ephemeral Realtime credential — subscribers only.
 *
 * The returned `ek_...` value expires in about a minute, so a stolen one is
 * worth almost nothing, which is why the app is never given the real key.
 */
/**
 * Credentials for one live call.
 *
 * Two providers are supported and the server picks, so switching does not need
 * an app release:
 *
 *   ElevenLabs Agents — preferred when configured. Turn-taking, interruption,
 *     speech recognition and the voice are all handled by the agent, which is
 *     configured at elevenlabs.io rather than here. The teaching prompt lives
 *     on the agent; the per-learner details travel as dynamic variables.
 *   OpenAI Realtime — the fallback. The teaching prompt is sent from here.
 *
 * Either way the credential is short-lived and minted per call, so the app
 * never holds anything worth stealing.
 */
async function liveSession(request, env, origin) {
  const body = await safeJson(request);
  const userId = String(body.userId ?? '');

  // The gate. Fails closed: no verified entitlement, no call. This is the only
  // check that matters — the app's own paywall is just the polite version.
  if (!(await hasPremium(env, userId))) {
    return json(
      { error: 'Live voice is part of Voix Premium.', code: 'not_subscribed' },
      402,
      origin,
    );
  }

  if (env.ELEVENLABS_API_KEY && env.ELEVENLABS_AGENT_ID) {
    return await elevenLabsSession(env, origin);
  }
  if (env.OPENAI_API_KEY) {
    return await openAiSession(body, env, origin, userId);
  }
  return json({ error: 'Live voice is not configured.' }, 500, origin);
}

/**
 * A signed WebSocket URL for the ElevenLabs agent.
 *
 * The agent has `enable_auth` on, so this URL is the only way in. It is
 * single-use and expires in minutes; without it the agent id alone is
 * worthless, which is what stops someone unpacking the APK and running up a
 * bill on your account.
 */
async function elevenLabsSession(env, origin) {
  const response = await fetch(
    `${ELEVENLABS}/convai/conversation/get-signed-url` +
      `?agent_id=${encodeURIComponent(env.ELEVENLABS_AGENT_ID)}`,
    { headers: { 'xi-api-key': env.ELEVENLABS_API_KEY } },
  );

  if (!response.ok) {
    console.error('signed-url failed', response.status, await response.text());
    return json({ error: 'Could not start a voice session.' }, 502, origin);
  }

  const data = await response.json();
  return json(
    {
      provider: 'elevenlabs',
      url: data.signed_url,
      // The agent is configured for 16 kHz in both directions. Sent rather
      // than hard-coded in the app so changing it in the ElevenLabs dashboard
      // does not need an app release — a mismatch here is not an error, it is
      // chipmunk audio.
      sampleRate: 16000,
    },
    200,
    origin,
  );
}

async function openAiSession(body, env, origin, userId) {
  const response = await fetch(`${OPENAI}/realtime/client_secrets`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      safety_identifier: userId,
      expires_after: { anchor: 'created_at', seconds: 60 },
      session: {
        type: 'realtime',
        // Server-side so the model and the teaching prompt can change without
        // an app update, and so the app cannot ask for a costlier model.
        model: env.REALTIME_MODEL,
        instructions: tutorInstructions(body, { spoken: true }),
        audio: {
          input: {
            format: { type: 'audio/pcm', rate: 24000 },
            transcription: { model: env.TRANSCRIBE_MODEL ?? 'whisper-1' },
            turn_detection: { type: 'server_vad', silence_duration_ms: 700 },
          },
          output: {
            format: { type: 'audio/pcm', rate: 24000 },
            voice: body.voice === 'female' ? 'shimmer' : 'verse',
            // Slightly under natural pace: a learner cannot follow a reply
            // delivered at native speed.
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
  return json(
    {
      provider: 'openai',
      token: data.value,
      expiresAt: data.expires_at,
      model: env.REALTIME_MODEL,
      sampleRate: 24000,
    },
    200,
    origin,
  );
}

/** The tutor: one reply, or one end-of-session report. */
async function chat(request, env, origin) {
  if (!env.OPENAI_API_KEY) {
    return json({ error: 'The tutor is unavailable right now.' }, 503, origin);
  }
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
 * Explains a single word.
 *
 * Free for everyone, deliberately. Looking up a word is the moment a learner
 * is most likely to give up on a sentence, and putting that behind a paywall
 * would make the app worse at the thing it exists for. It is also cheap: one
 * short reply from a small model, capped below.
 *
 * The app already derives the inflected forms on the phone, so this is asked
 * only for what rules cannot produce.
 */
async function explainWord(request, env, origin) {
  if (!env.OPENAI_API_KEY) {
    return json({ error: 'Word help is unavailable right now.' }, 503, origin);
  }

  const body = await safeJson(request);
  const word = String(body.word ?? '').trim().slice(0, 60);
  if (!word) return json({ error: 'No word given.' }, 400, origin);

  const level = ['beginner', 'intermediate', 'advanced'].includes(body.level)
    ? body.level
    : 'beginner';
  const native = String(body.nativeLanguage ?? 'Telugu').slice(0, 40);

  const response = await fetch(`${OPENAI}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: env.CHAT_MODEL,
      messages: [
        { role: 'system', content: wordInstructions(level, native) },
        { role: 'user', content: word },
      ],
      max_completion_tokens: 700,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    console.error('word failed', response.status, await response.text());
    return json({ error: 'Could not explain that word.' }, 502, origin);
  }

  const data = await response.json();
  return json({ content: data.choices?.[0]?.message?.content ?? '' }, 200, origin);
}

function wordInstructions(level, native) {
  return [
    `You explain single English words to a ${level} learner whose first`,
    `language is ${native}.`,
    ``,
    `Reply with JSON only, in exactly this shape:`,
    `{`,
    `  "word": string,`,
    `  "pronunciation": string,`,
    `  "senses": [{ "partOfSpeech": string, "definition": string,`,
    `               "examples": [string, string] }],`,
    `  "origin": string,`,
    `  "nativeMeaning": string,`,
    `  "synonyms": [string]`,
    `}`,
    ``,
    `Rules:`,
    `- "pronunciation" is a plain respelling a ${native} speaker can read`,
    `  aloud, like "KOM-fer-tuh-bul". Never IPA — a learner who cannot read`,
    `  IPA is not helped by it.`,
    `- Give every common sense of the word, not only the first. A word with`,
    `  two lives — "book" the object and "book" the act of reserving — is`,
    `  exactly the word someone is asking about.`,
    `- Definitions in words a ${level} learner already knows. Explaining a`,
    `  hard word with three harder ones is the most common way to fail here.`,
    `- Examples must be ordinary sentences someone would really say, and`,
    `  short enough to remember.`,
    `- "origin" is one or two sentences of real etymology, in plain language.`,
    `  Where the word came from is what makes a strange spelling finally make`,
    `  sense, so include the older form and the language it came from.`,
    `- "nativeMeaning" is the word in ${native}, in that language's own`,
    `  script.`,
    `- If the word is misspelled, answer for the word you believe was meant`,
    `  and say so in the first definition.`,
    `- Do not include inflected forms; the app derives those itself.`,
  ].join('\n');
}

/**
 * The teaching prompt.
 *
 * Lives on the server so it can be improved without an app release — prompt
 * wording is the thing you will tune most often.
 */
function tutorInstructions(body, { spoken = false } = {}) {
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
    ...(spoken ? _spokenRules(level, native) : []),
  ].join('\n');
}

/**
 * Extra rules for the live voice call.
 *
 * Speaking is not writing. The learner cannot re-read a correction, cannot see
 * spelling, and cannot skim — anything not understood the first time is simply
 * lost. These rules exist so the call teaches rather than merely chats, which
 * is the whole point of it: it is a language lesson conducted as a phone call,
 * not an assistant that happens to talk.
 */
function _spokenRules(level, native) {
  return [
    ``,
    `You are speaking out loud, on a live call:`,
    `- Speak slowly and clearly, and keep each turn under about 20 seconds. A learner cannot re-read you.`,
    `- Leave the learner room to talk. Silence is them thinking, not a cue for you to fill it.`,
    `- Never spell things out letter by letter or read punctuation aloud.`,
    `- When you correct something, say the whole corrected sentence back naturally, then move on. Do not stack several corrections into one turn — pick the one that most got in the way of being understood.`,
    `- If the learner goes quiet or says they are stuck, offer them the sentence to repeat after you. Repetition out loud is how speaking improves.`,
    `- If you genuinely cannot make out what they said, say so plainly and ask them to say it again. Do not guess and answer the wrong question.`,
    `- Praise a good sentence the moment it happens, briefly. On a call, encouragement has to be immediate to land.`,
    `- A ${level} learner will hesitate and restart sentences. Wait. Do not finish their sentences for them.`,
    `- You may drop one short phrase of ${native} to unblock them, then return to English straight away.`,
  ];
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
  // Confirming a purchase must never be rate-limited: someone who has just
  // paid and cannot be verified is someone about to demand a refund.
  if (pathname === '/v1/verify') return { ok: true };
  if (!env.VOIX_KV) return { ok: true };

  // Live voice is billed per minute of audio, so it gets its own, much
  // tighter cap than text.
  const isVoice = pathname === '/v1/session';
  const limit = Number(
    isVoice ? env.DAILY_VOICE_LIMIT ?? 12 : env.DAILY_CHAT_LIMIT ?? 300,
  );
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

// ── Entitlement ───────────────────────────────────────────────────────────

/**
 * Records that an account is a subscriber until [expiresAt].
 *
 * Stored with a TTL matching the subscription's own expiry, so premium lapses
 * on its own if the learner stops paying and the app never checks in again.
 */
async function grantPremium(env, userId, expiresAt) {
  if (!env.VOIX_KV) {
    console.error('grantPremium: VOIX_KV is not bound — entitlement not stored');
    return;
  }
  const ttl = Math.max(60, Math.floor((expiresAt - Date.now()) / 1000));
  await env.VOIX_KV.put(`premium:${userId}`, String(expiresAt), {
    expirationTtl: ttl,
  });
}

/**
 * Whether this account may use paid features.
 *
 * Fails **closed**: with no KV bound there is no way to know who paid, and
 * guessing "yes" would hand a per-minute-billed feature to everyone.
 */
async function hasPremium(env, userId) {
  if (!userId || !env.VOIX_KV) return false;
  const until = Number((await env.VOIX_KV.get(`premium:${userId}`)) ?? 0);
  return until > Date.now();
}

// ── Google service account ────────────────────────────────────────────────

/**
 * Exchanges the service account key for a short-lived Google access token.
 *
 * Signed here with WebCrypto rather than with a library: Workers have no
 * Node crypto, and the whole flow is one JWT and one POST.
 */
async function googleAccessToken(env) {
  const cached = _tokenCache;
  if (cached && cached.expiresAt > Date.now() + 60_000) return cached.token;

  const credentials = JSON.parse(env.PLAY_SERVICE_ACCOUNT_JSON);
  const now = Math.floor(Date.now() / 1000);

  const claim = {
    iss: credentials.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const unsigned =
    `${base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.` +
    `${base64url(JSON.stringify(claim))}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(credentials.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  const assertion = `${unsigned}.${base64urlBytes(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google token exchange failed: ${response.status}`);
  }

  const data = await response.json();
  _tokenCache = {
    token: data.access_token,
    expiresAt: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
  return _tokenCache.token;
}

/**
 * Per-isolate access token cache.
 *
 * Workers reuse an isolate across requests, so this saves a round trip on most
 * calls. It is not shared between isolates, which is fine — the worst case is
 * fetching a token that another isolate already has.
 */
let _tokenCache = null;

function base64url(text) {
  return base64urlBytes(new TextEncoder().encode(text));
}

function base64urlBytes(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Strips the PEM armour and newlines, leaving the DER bytes WebCrypto wants. */
function pemToBytes(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
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
