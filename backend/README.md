# Voix backend

A single Cloudflare Worker that holds your API keys so the app never has to. It
gives the tutor a real brain: it answers what the learner actually said,
translates, and explains mistakes in their own language. It also decides who is
allowed a live call, and hands out the short-lived credentials for one.

For everyone who has not paid, speaking and listening stay on the phone —
Android's own speech recogniser and text-to-speech — so no audio reaches this
Worker and none of it costs anything.

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

### 2b. The live call: pick a provider

The live call — the one where the tutor talks back like a phone call — can run
on either of two services. **You only need one.** The Worker picks ElevenLabs
if you have configured it, and OpenAI otherwise, so switching later is two
commands and no app update.

**ElevenLabs Agents (recommended).** The agent handles turn-taking,
interruption, speech recognition and the voice, and it holds the teaching
prompt, so you can improve how the tutor teaches from a web page without
touching any code.

An agent has already been created in your workspace:

| | |
|---|---|
| Name | Voix English Tutor |
| Agent ID | `agent_2901kzwd5emsfg3ts393enmpb0we` |
| Voice | 16 kHz, `eleven_flash_v2` |
| Call length cap | 10 minutes |
| Authentication | **on** — the agent ID alone is useless without a signed URL from this Worker |

Set both of these:

```bash
npx wrangler secret put ELEVENLABS_API_KEY
npx wrangler secret put ELEVENLABS_AGENT_ID   # agent_2901kzwd5emsfg3ts393enmpb0we
```

Get the API key from elevenlabs.io → your profile → API Keys. Same rule as
every other key here: it goes into this command and nowhere else.

**OpenAI Realtime.** Nothing extra to set — if `OPENAI_API_KEY` is present and
ElevenLabs is not configured, the live call uses it. The teaching prompt then
lives in `worker.js` rather than on an agent.

You can also skip the live call entirely. Without either provider configured,
`/v1/session` returns an error, the app keeps working, and practice happens
through the phone's own recogniser at no cost.

### 3. Turn on the spending cap

This is the step people skip and regret. Without it, one retry loop in a bad
build can run up a large bill overnight.

```bash
npx wrangler kv namespace create VOIX_KV
```

It prints an `id`. Open `wrangler.toml`, uncomment the `[[kv_namespaces]]`
block, and paste the id in.

### 4. Check the model name, then deploy

Open `wrangler.toml` and check `CHAT_MODEL` against
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

Forget the flag and the app simply runs on the on-device tutor — no crash, no
error, just the scripted replies. If the tutor seems to have stopped
understanding you, this flag is the first thing to check.

### 6. Check it works

```bash
curl -X POST https://voix-backend.your-name.workers.dev/v1/chat \
  -H "Content-Type: application/json" \
  -H "x-voix-app-token: YOUR_APP_TOKEN" \
  -H "x-voix-device: test-device" \
  -d '{"level":"beginner","nativeLanguage":"Telugu","scenario":"ordering food",
       "messages":[{"role":"user","content":"I want eat pizza"}]}'
```

A working response looks like:

```json
{"content":"{\"reply\":\"Of course! What would you like to drink?\", ...}"}
```

If you get `{"error":"Not authorised."}` the app token is wrong. If you get
`{"error":"The tutor is unavailable right now."}`, run `npx wrangler tail` in
one terminal and repeat the curl in another — the real OpenAI error will be
printed there.

---

## Watch what it costs

Text is the cheap way to do this — you are sending a few sentences at a time to
a small model, not streaming audio. Even so:

1. Set a hard spending limit in your OpenAI account
   (Settings → Limits → Usage limits). Do this **today**, not later. It is the
   only cap OpenAI enforces for you; everything here is a second line of
   defence.
2. Watch OpenAI's usage page for the first week, so you learn what a real
   conversation actually costs before anyone else is using the app.

## Endpoints

| Endpoint | Used by | What it does |
| --- | --- | --- |
| `POST /v1/chat` | Every tutor reply, and the end-of-session report | Returns the tutor's reply, corrections and scores as JSON |
| `POST /v1/verify` | After a Play purchase | Asks Google whether the purchase is real, and records the entitlement |
| `POST /v1/session` | Starting a live call | Returns credentials for one call — subscribers only |

They require the `x-voix-app-token` header and accept an `x-voix-device`
header, used for the daily cap.

`/v1/session` answers with whichever provider is configured, and the app
speaks that protocol:

```jsonc
// ElevenLabs
{ "provider": "elevenlabs", "url": "wss://…signed…", "sampleRate": 16000 }

// OpenAI
{ "provider": "openai", "token": "ek_…", "model": "…", "sampleRate": 24000 }
```

It returns **402** for anyone this Worker has not verified as a subscriber.
That check is the real paywall — the app's own is a courtesy, because an APK
can be edited and this Worker cannot.

## Changing how the tutor teaches

Where the teaching prompt lives depends on which provider carries the call:

- **ElevenLabs** — on the agent, at
  [elevenlabs.io](https://elevenlabs.io) → Agents → Voix English Tutor →
  System prompt. Edit and save; the next call uses it. The prompt refers to
  `{{level}}`, `{{native_language}}` and `{{scenario}}`, which the app fills in
  per learner — keep those placeholders or the tutor stops adapting to who it
  is talking to.
- **OpenAI, and all text replies** — the `tutorInstructions()` function in
  `worker.js`. Change it and `npx wrangler deploy`.

Both are deliberately off the phone: prompt wording is what you will tune most
often, and neither route needs an app update and a Play review to change.

## Honest status

None of this has been run against a live API. It was written against the
published documentation, with no keys available where it was built. Expect to
fix something on the first deploy — `npx wrangler tail` shows you exactly what
the upstream service is complaining about.

The one part that *has* been verified is the ElevenLabs agent: it was created
through the API, its configuration was read back, and authentication was
confirmed on. What has not been verified is a real call flowing through it.

If the app cannot reach this Worker for any reason, it falls back to the
on-device tutor rather than showing an error. That is deliberate, but it also
means a misconfigured backend looks like "the tutor got dumb" rather than like
a failure. Test with the curl above before blaming the app.
