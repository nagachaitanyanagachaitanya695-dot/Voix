# Privacy Policy for Voix

**Last updated: [DATE]**

> **Before you publish this**, replace every `[BRACKETED]` placeholder, and read
> the whole thing against what your build actually does. This was written
> against the code in this repository as of the last commit — if you change what
> the app collects, this document is wrong until you update it.
>
> This is a starting draft prepared by a developer, **not legal advice**. If you
> are handling data from children, from the EU/UK, or at scale, have a lawyer
> read it.
>
> Delete this box before publishing.

---

Voix ("we", "us") is an AI language-learning app operated by
**[YOUR NAME OR COMPANY]**. This policy explains what the app collects, why,
who else can see it, and how to get rid of it.

We have tried to keep this readable. If anything here is unclear, email
**[YOUR CONTACT EMAIL]** and ask.

## The short version

- Your practice, progress and conversation transcripts are stored **on your
  phone**.
- If you sign in with an account, that same information is also **backed up to
  our Firebase database** so you don't lose it when you change or reset your
  phone.
- Your **voice is not recorded or stored by Voix**. It is passed to your
  phone's own speech recognition service to be turned into text. On most
  Android phones that service is Google's, and it may send the audio to Google
  to process.
- We run **no advertising, no analytics, and no third-party trackers**. We do
  not sell or share your data with anyone for marketing.

## What we collect

### 1. Information you give us

**If you create an account** (email, Google, or Apple sign-in), we receive:

- your email address;
- your name, and your profile photo if your Google or Apple account has one;
- a Firebase user ID that identifies your account.

If you use **Continue as Guest**, no account is created and none of the above
is collected. Your progress stays on the device only.

**During onboarding** you tell us your native language, the language you are
learning, your self-assessed level, your occupation category, and your learning
goal. This is used to choose your lessons and set the tutor's difficulty.

### 2. Information the app creates as you use it

- XP, level, current and longest streak, daily goal, minutes practised;
- which lessons you have completed and which achievements you have unlocked;
- your conversation transcripts, and the feedback reports generated from them
  (corrections, suggested vocabulary, fluency/pronunciation/confidence scores);
- phrases you save;
- your settings: theme, reminder times, tutor voice, sound and haptics.

All of this is written to your device's local storage. If you have an account,
it is also written to your record in our database.

### 3. Your voice

Voix asks for microphone permission so you can speak to the tutor.

**Voix does not record, save, or upload audio.** No audio file is ever written
to your device or sent to our servers. The microphone is only open while you are
actively speaking to the tutor, and closes when you stop.

What happens instead is that the audio stream is handed to **your phone's
built-in speech recognition service**, which returns text. Voix keeps the text,
not the sound.

> **Important:** that speech recognition service is not part of Voix and is not
> controlled by us. On most Android devices it is provided by Google, and
> **Google may transmit the audio to its own servers** to transcribe it,
> governed by [Google's Privacy Policy](https://policies.google.com/privacy).
> Some devices and languages support fully on-device recognition. If this
> matters to you, check your device's voice input settings, or type to the tutor
> instead of speaking — every part of the app works with typed input.

The same applies in reverse when the tutor speaks: Voix passes text to your
phone's text-to-speech engine, which is likewise provided by your device.

### 4. What we do **not** collect

- No advertising identifiers, and no advertising of any kind.
- No analytics or usage-tracking SDKs.
- No crash-reporting SDK.
- No location data.
- No contacts, photos, files, or any other app's data.
- No payment information — the app does not currently charge for anything.

## Who else can see your data

Only these, and only for the purposes described:

| Who | What they get | When |
| --- | --- | --- |
| **Google Firebase** (Authentication + Cloud Firestore) | Your account identity and your learning profile | Only if you create an account |
| **Google** (Play Services / speech recognition) | Audio, to transcribe it | Only while you are speaking to the tutor, and only if your device's recogniser is Google's |
| **Google or Apple** (Sign-In) | Confirms your identity to us | Only if you choose that sign-in method |

Firebase is operated by Google and processes data on our behalf under Google's
terms. See [Firebase's privacy documentation](https://firebase.google.com/support/privacy).

**We do not sell your personal information, and we do not share it with
advertisers or data brokers.**

We will only disclose data otherwise if we are legally required to, or where it
is necessary to protect someone's safety.

## Where your data is stored and for how long

Data on your phone stays there until you delete it or uninstall the app.

Account data is stored in Firebase in **[YOUR FIRESTORE REGION, e.g. asia-south1
(Mumbai)]** and is kept while your account exists. Delete your account and we
delete the record.

## Deleting your data

**In the app:** Profile → Settings → Privacy → **Delete Account**. This
permanently removes your profile, progress, streak and saved conversations from
the device *and* from our database. It cannot be undone.

**Uninstalling** removes everything stored on the device. If you had an account,
your backup remains until you delete the account — so that reinstalling
restores your progress.

**By email:** write to **[YOUR CONTACT EMAIL]** from the address on your
account and we will delete it. We aim to respond within 30 days.

## Your rights

Depending on where you live, you may have the right to access a copy of your
data, correct it, delete it, restrict how it is used, or object to its use —
for example under the **GDPR** in the EU/UK, or India's **Digital Personal Data
Protection Act, 2023**. Most of these you can exercise directly in the app; for
anything else, email **[YOUR CONTACT EMAIL]**.

Where consent is our legal basis — microphone access in particular — you can
withdraw it at any time in your phone's app permission settings. The app will
keep working with typed input.

## Children

Voix is not directed at children under 13 (or the equivalent minimum age where
you live), and we do not knowingly collect data from them. If you believe a
child has given us personal information, email **[YOUR CONTACT EMAIL]** and we
will remove it.

> If you *do* intend to target children, this section is not sufficient — Play's
> Families policy and COPPA both impose extra requirements.

## Security

Account data is transmitted over encrypted connections and protected by
Firebase security rules that permit each account to read and write only its own
record. Data on your device is stored in the app's private storage area, which
other apps cannot read.

No system is perfectly secure, and we cannot guarantee absolute security.

## Changes to this policy

If we change what the app collects, we will update this page and change the date
at the top. Significant changes will be announced in the app.

## Contact

**[YOUR NAME OR COMPANY]**
Email: **[YOUR CONTACT EMAIL]**
[YOUR POSTAL ADDRESS — required in some jurisdictions]

---

# Notes for the developer

*(Not part of the published policy — delete before publishing.)*

## Hosting it

Play requires a public URL that works without logging in. The cheapest route:

1. Copy the policy (without these notes) into a new repo, or into a `docs/`
   folder in a public one, as `index.md`.
2. Repo **Settings → Pages → Source: main branch, /docs folder**.
3. The URL is `https://<username>.github.io/<repo>/`.
4. Paste it into **Play Console → App content → Privacy policy**, and into the
   Play Store listing.

Keep it reachable forever. A dead privacy-policy link gets apps pulled.

## Filling in the Data Safety form

Play's Data Safety declaration must match this policy or the app can be
rejected. Based on what the code currently does:

| Play question | Answer |
| --- | --- |
| Does your app collect or share user data? | **Yes** |
| Personal info → Name | Collected, not shared. Optional (account only). Purpose: App functionality, Account management |
| Personal info → Email address | Collected, not shared. Optional (account only). Purpose: App functionality, Account management |
| Personal info → User IDs | Collected, not shared. Purpose: App functionality, Account management |
| Photos → Profile photo | Collected, not shared. Optional. Purpose: App functionality |
| Audio → Voice or sound recordings | **Not collected** — the app does not store or transmit audio itself. Declare the microphone permission and explain in-app. |
| App activity → Other user-generated content | Collected (transcripts, saved phrases), not shared. Purpose: App functionality |
| App activity → App interactions | Collected (progress, streaks), not shared. Purpose: App functionality |
| Is data encrypted in transit? | **Yes** |
| Can users request data deletion? | **Yes** — in-app, Profile → Settings → Privacy → Delete Account |

The Audio row is the one to think about carefully. Voix genuinely does not
collect audio — it hands it to the OS recogniser. Play's guidance is that data
processed by the device's own services and never received by you is not
"collected" by your app. Declaring it anyway is the safer, more conservative
answer if you are unsure.

## Keep this accurate when you change the app

Each of these makes the policy above wrong until you update it:

- **Enabling the Anthropic backend** (`docs/BACKEND.md`). Conversation text
  would then leave the device and be sent to a third-party AI provider. That is
  a material change: you must add Anthropic to the third-party table, say what
  is sent and how long it is kept, and re-declare data sharing on the Data
  Safety form.
- **Adding analytics or crash reporting.** The "no analytics" claim above is
  currently true and stops being true the moment you add Firebase Analytics or
  Crashlytics.
- **Adding payments or a Pro tier.**
- **Adding push notifications via FCM** — device tokens are personal data. The
  current reminders are scheduled locally on the device and involve no server.
- **Setting `onDevice: true`** in `SpeechService` — that would strengthen the
  voice section, since audio would then stay on the phone.
