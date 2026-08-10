# Voix backend

A single Cloudflare Worker that holds your OpenAI API key so the app never
has to. It gives the tutor a real brain: it answers what the learner actually
said, translates, and explains mistakes in their own language.

Speaking and listening stay on the phone — Android's own speech recogniser and
text-to-speech — so no audio ever reaches this Worker and none of it costs
anything.

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

It requires the `x-voix-app-token` header and accepts an `x-voix-device`
header, used for the daily cap.

## Changing how the tutor teaches

The teaching prompt is the `tutorInstructions()` function in `worker.js`. It is
deliberately on the server: prompt wording is what you will tune most often, and
here you can change it and `npx wrangler deploy` in seconds instead of shipping
an app update and waiting for Play review.

## Honest status

None of this has been run. It was written against OpenAI's published API
documentation, but there was no OpenAI key and no way to call the API from
where it was built. Expect to fix something on the first deploy — `npx wrangler
tail` shows you exactly what OpenAI is complaining about.

If the app cannot reach this Worker for any reason, it falls back to the
on-device tutor rather than showing an error. That is deliberate, but it also
means a misconfigured backend looks like "the tutor got dumb" rather than like
a failure. Test with the curl above before blaming the app.
