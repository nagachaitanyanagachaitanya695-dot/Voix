# Voix Premium — subscriptions

₹9 for the first week, then ₹299 a month, sold through Google Play Billing.
Premium unlocks live voice-to-voice conversation.

## Why Play Billing and not your website

You asked about selling on a website. Google Play's payments policy restricts
selling in-app digital features through anything other than Play Billing, and
apps get removed for it after they have users.

India does have an
[alternative billing option](https://support.google.com/googleplay/android-developer/answer/13306652),
but it is not a way around the fee: you must still offer Play billing alongside
it, report every external sale through Google's `ExternalTransactions API`, and
Google still charges its service fee minus 4%. More work, more risk, marginal
saving.

Play Billing also **supports UPI in India**, which was the reason you wanted a
website in the first place. So the site is still worth building — for marketing
and to host your privacy policy — just not as the checkout.

---

## The two-price setup

**Do not create two products.** One subscription, one base plan, with the ₹9
first week configured as an *introductory price* — that is what Play's own
machinery is for, and it means the app never has to work out which period a
learner is in.

In **Play Console → Monetise → Subscriptions**:

1. **Create subscription**
   - Product ID: **`voix_premium`** — this must match `SubscriptionService.productId`
     in the app exactly, and **it can never be changed** once created.
   - Name: `Voix Premium`

2. **Add a base plan**
   - Type: **Auto-renewing**
   - Billing period: **Monthly**
   - Price: **₹299**

3. **Add an offer** on that base plan
   - Eligibility: **New customer acquisition**
   - Phase: **Introductory price**, ₹9, for **1 week**, then it rolls onto ₹299/month
   - This is the "₹9 first week" the paywall advertises.

4. **Activate** both the subscription and the offer. An inactive subscription
   returns "product not found" in the app and the paywall shows
   "not available on this device".

---

## Letting the server verify purchases

The app sends every purchase to your Worker, which asks Google whether it is
real. For that the Worker needs permission to read your Play purchases.

### 1. Create a service account

1. [Google Cloud Console](https://console.cloud.google.com) → **IAM & Admin →
   Service Accounts → Create service account**. Name it `voix-play-verifier`.
2. Once created: **Keys → Add key → Create new key → JSON**. A `.json` file
   downloads. **This file is a credential — treat it like a password.**
3. In **Play Console → Users and permissions → Invite new user**, invite the
   service account's email (it looks like
   `voix-play-verifier@your-project.iam.gserviceaccount.com`).
4. Give it the **View financial data** permission on your app, and grant it
   access to the Voix app only.

> Google's permission changes can take a few hours to propagate. A `401` from
> the verification endpoint immediately after setup usually just means "not
> yet".

### 2. Give it to the Worker

```bash
cd backend
npx wrangler secret put PLAY_SERVICE_ACCOUNT_JSON
```

Paste the **entire contents** of the JSON file when prompted — the whole thing,
including the braces. Like your OpenAI key, it lives only in Cloudflare.

Check `ANDROID_PACKAGE_NAME` in `wrangler.toml` matches your `applicationId`
(`com.voix.voix`), then:

```bash
npx wrangler deploy
```

---

## How entitlement actually works

```
Play purchase → app sends the token to /v1/verify
              → Worker asks Google: is this real and active?
              → Google answers
              → Worker stores premium:{userId} in KV until the expiry Google gave
              → /v1/session refuses anyone without that entry
```

Three things matter here:

**The server decides, not the app.** The app's `isPro` flag only controls what
the UI offers. Anyone can unzip an APK and flip a boolean; they cannot flip one
on your Worker. `/v1/session` — the endpoint that mints credentials for the
per-minute-billed voice feature — checks KV, not the app's word.

**It fails closed.** If KV is not bound, or Google is unreachable, nobody gets
premium. An outage must not become free access to a metered feature.

**Premium expires on its own.** The KV entry is written with a TTL matching the
subscription's own expiry time. If someone cancels and never opens the app
again, their access lapses without anything having to run.

> **KV is not optional here.** Without it bound, `grantPremium` logs an error
> and stores nothing, so a paying subscriber is verified and then still refused.
> Do step 3 of `backend/README.md` before taking any money.

---

## Testing without spending money

1. **Play Console → Setup → License testing** — add your own Google account.
   Licence testers get the real purchase flow with test payment methods, and
   subscriptions renew in minutes rather than months.
2. Upload a build to **internal testing** — Play Billing does not work in a
   debug build installed over USB. It must come from Play.
3. Buy the subscription as a tester and confirm:
   - The paywall shows a real price from Play, not the fallback wording.
   - After purchase, the live-call entry point unlocks.
   - `npx wrangler tail` shows `/v1/verify` returning `premium: true`.
   - Uninstall, reinstall, tap **Restore purchases** — premium comes back.

That last one is not optional. Play requires restore to work, and it is the
path someone takes after changing phones.

---

## What is not built

- **No server-to-server notifications.** Google can push subscription events
  (renewals, cancellations, refunds) to a webhook via Pub/Sub. Without it, a
  refunded subscriber keeps access until their KV entry expires. Worth adding
  before you have real volume.
- **No grace-period messaging.** The Worker treats `IN_GRACE_PERIOD` as
  entitled, which is right, but the app never tells the learner their payment
  failed.
- **Guest accounts.** Entitlement is keyed on the account id. A guest who
  subscribes and later signs in properly gets a different id and loses access.
  Require sign-in before the paywall, or link the two ids.
- **None of this has been run.** There is no Play Console, no service account
  and no device here. The purchase-handling logic is covered by tests in
  `test/subscription_service_test.dart`; the Google round trip is not, and
  cannot be until you test it as a licence tester.
