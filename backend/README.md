# Voix backend

A single Cloudflare Worker that holds your OpenAI API key so the app never
has to.

**Why this exists:** an APK is a zip file. A key compiled into the app can be
extracted in about thirty seconds by anyone who downloads it, and then they are
spending your money. There is no way to hide a secret inside a mobile app —
this is not a Flutter limitation, it is true of every app on every store. The
only real fix is to keep the key on a machine you control.

```
phone  →  this Worker (holds the key)  →  OpenAI
```

Cloudflare's free tier covers 100,000 requests a day, which is far more than
you will need. No credit card is required.

---

## Deploy it

You need [Node.js](https://nodejs.org) installed. Everything below is typed in
a terminal, in this `backend/` folder.

### 1. Log in to Cloudflare

```bash
npx wrangler login
```

A browser window opens. Sign in (create a free account if you don't have one)
and approve.

### 2. Give it your OpenAI key

```bash
npx wrangler secret put OPENAI_API_KEY
```

It will prompt you to paste the key. **This is the only place your key ever
goes.** It is stored encrypted by Cloudflare. It is not in this repository, not
in the app, and nobody — including me — can read it back out.

Now make up a second, different random string and set it as the app token. This
stops strangers who discover your Worker's URL from using it:

```bash
npx wrangler secret put APP_TOKEN
```

Anything unguessable works, e.g. the output of:

```bash
openssl rand -hex 24
```

Keep that value — you paste it into the app in step 5.

### 3. Turn on the spending cap

This is the step people skip and regret. Without it, one bug that reconnects in
a loop can run up a large bill overnight.

```bash
npx wrangler kv namespace create VOIX_KV
```

It prints an `id`. Open `wrangler.toml`, uncomment the `[[kv_namespaces]]`
block, and paste the id in.

### 4. Check the model names, then deploy

Open `wrangler.toml` and check `REALTIME_MODEL` and `CHAT_MODEL` against
[OpenAI's current model list](https://platform.openai.com/docs/models). Model
names change; a stale one fails at runtime with a `400`.

```bash
npx wrangler deploy
```

It prints a URL like `https://voix-backend.your-name.workers.dev`. That is your
backend.

### 5. Point the app at it

In the project root, copy `env.example.json` to `env.json` and fill in the URL
from step 4 and the `APP_TOKEN` from step 2:

```json
{
  "VOIX_BACKEND_URL": "https://voix-backend.your-name.workers.dev",
  "VOIX_APP_TOKEN": "the token from step 2"
}
```

`env.json` is gitignored, so it never reaches GitHub. Pass it on every build:

```bash
flutter run --dart-define-from-file=env.json
flutter build appbundle --release --dart-define-from-file=env.json
```

Forget the flag and the app simply runs in its free, on-device mode — no crash,
no error, just the scripted tutor. If live voice is mysteriously missing from
the Practice screen, this flag is the first thing to check.

### 6. Check it works

```bash
curl -X POST https://voix-backend.your-name.workers.dev/v1/session \
  -H "Content-Type: application/json" \
  -H "x-voix-app-token: YOUR_APP_TOKEN" \
  -H "x-voix-device: test-device" \
  -d '{"level":"beginner","nativeLanguage":"Telugu","scenario":"ordering food"}'
```

A working response looks like:

```json
{"token":"ek_...","expiresAt":1234567890,"model":"gpt-realtime"}
```

If you get `{"error":"Not authorised."}` the app token is wrong. If you get
`{"error":"Could not start a voice session."}`, run
`npx wrangler tail` in one terminal and repeat the curl in another — the real
OpenAI error will be printed there.

---

## Watch what it costs

Live voice-to-voice is billed per minute of audio, in **both** directions, and
it is the expensive part of this app by a wide margin. Text chat is cheap by
comparison.

Before you let anyone else use the app:

1. Set a hard spending limit in your OpenAI account
   (Settings → Limits → Usage limits). Do this **today**, not later. It is the
   only cap OpenAI enforces for you.
2. Keep `DAILY_VOICE_LIMIT` low while you learn what a session actually costs.
   Twelve sessions per device per day is already generous.
3. Watch OpenAI's usage page for the first week.

## Endpoints

| Endpoint | Used by | What it does |
| --- | --- | --- |
| `POST /v1/session` | Live voice mode | Mints an ephemeral Realtime token, valid ~60s |
| `POST /v1/chat` | Text tutor and end-of-session reports | Returns the tutor's reply as JSON |

Both require the `x-voix-app-token` header and accept an `x-voix-device`
header used for the daily cap.

## Changing how the tutor teaches

The teaching prompt is the `tutorInstructions()` function in `worker.js`. It is
deliberately on the server: prompt wording is what you will tune most often, and
here you can change it and `npx wrangler deploy` in seconds instead of shipping
an app update and waiting for Play review.

## Honest status

None of this has been run. It was written against OpenAI's published Realtime
documentation, but I have no OpenAI key and no way to call the API from where
this was built. Expect to fix something on the first deploy — `npx wrangler
tail` shows you exactly what OpenAI is complaining about.
