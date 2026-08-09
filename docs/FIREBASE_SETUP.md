# Firebase setup

The Firebase integration is **written and wired**; it is only switched off,
because `lib/firebase_options.dart` still holds placeholder values.

Until you fill those in, the app runs on `LocalAuthRepository`: accounts live on
the device, Google and Apple sign-in return a "not configured" message, and a
reinstall loses every streak. Everything else works normally.

Once real values are in, `main()` initialises Firebase, `authRepositoryProvider`
switches to `FirebaseAuthRepository`, and the profile starts backing up to
Firestore. **No code changes are needed** — the switch is the config file.

---

## 1. Create the project

1. <https://console.firebase.google.com> → **Add project**.
2. Inside it, **Authentication → Get started**, and enable:
   - **Email/Password**
   - **Google**
   - **Apple** (only if you are also shipping on iOS)
   - **Anonymous** — this is what "Continue as Guest" uses. Miss it and the
     guest button fails with `operation-not-allowed`.
3. **Firestore Database → Create database**. Start in *production* mode; the
   rules in section 5 replace the defaults.

## 2. Register the Android app

**Add app → Android**, with package name `com.voix.voix` (it must match
`applicationId` in `android/app/build.gradle.kts`).

Google Sign-In will not work without your signing certificate's SHA-1
fingerprint. Add **both** — debug so you can test, release so it works in
production:

```bash
# Debug
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore -storepass android -keypass android

# Release — the keystore you made in docs/RELEASE.md
keytool -list -v -alias voix -keystore ~/voix-upload-key.jks
```

Paste each SHA-1 into Project settings → Your apps → Android → *Add
fingerprint*.

> If you use Play App Signing (Play re-signs your upload), also add the SHA-1
> that the Play Console shows under Setup → App signing. Google Sign-In breaks
> in production without it, and only in production — the single most common way
> to ship a broken login.

## 3. Fill in `lib/firebase_options.dart`

The easy route generates it for you:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

That overwrites `lib/firebase_options.dart` with your real values and drops
`android/app/google-services.json` in place.

It does **not** write `googleServerClientId`, which this app needs — set it by
hand. It is the **web** client id, not the Android one: the ID token Firebase
verifies is issued to the web client. Find it in `google-services.json` as the
`oauth_client` entry with `"client_type": 3`, or under Project settings →
General.

```dart
static const googleServerClientId = '1234567890-abcdef.apps.googleusercontent.com';
```

If you prefer to fill the file in by hand instead of running the CLI, copy
`apiKey` / `appId` / `messagingSenderId` / `projectId` from the console into the
`_android` and `_ios` constants. `isConfigured` flips as soon as the Android
`apiKey` no longer starts with `REPLACE_ME`.

> These values are not secrets — a Firebase `apiKey` identifies a project, it
> does not authorise anything. Your data is protected by the rules in section 5,
> which is why they are not optional.

## 4. Gradle

If you ran `flutterfire configure` and have a `google-services.json`, add the
plugin so it is read at build time. In `android/settings.gradle.kts`:

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

and in `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

If you filled in `firebase_options.dart` by hand and have no
`google-services.json`, you can skip this — `Firebase.initializeApp(options:)`
configures the SDK programmatically. Google Sign-In still works, because
`serverClientId` is passed in code.

Add the generated config to `.gitignore` either way:

```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

## 5. Firestore security rules

Paste these into **Firestore → Rules** and publish. Without them your default
rules either block everything or, worse, let any signed-in user read every other
user's profile.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // A learner may read and write exactly one document: their own.
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;

      allow create: if request.auth != null
                    && request.auth.uid == userId
                    && request.resource.data.id == userId;

      // The id can never be reassigned — that is the only field the client
      // must not be able to change, since it is what these rules key on.
      allow update: if request.auth != null
                    && request.auth.uid == userId
                    && request.resource.data.id == resource.data.id;

      allow delete: if request.auth != null && request.auth.uid == userId;
    }

    // Anything not matched above is denied.
  }
}
```

---

## What the code actually does

**`FirebaseAuthRepository`** (`lib/data/repositories/firebase_auth_repository.dart`)

- Email sign-up and log-in are separate paths — `isSignUp` comes from the toggle
  on the auth screen — so "no such account" and "already registered" produce
  the right message instead of a guess.
- Google uses `google_sign_in` 7.x (`GoogleSignIn.instance.authenticate()`) and
  exchanges the resulting ID token for a Firebase credential.
- Apple goes through `OAuthProvider('apple.com')`, which uses the native sheet
  on iOS and Firebase's hosted web flow on Android — no extra package.
- Guest is `signInAnonymously()`. The profile keeps working and can be upgraded
  to a real account later without losing progress.
- Every Firebase error code is mapped to a sentence a learner can act on.

**`FirestoreProfileSync`** (`lib/data/repositories/profile_sync.dart`)

- Mirrors the profile to `users/{uid}`, debounced to one write per 5 seconds —
  XP moves on nearly every tap, and a write per tap would be both slow and
  expensive.
- Flushed before sign-out, so the last session is never lost.
- `LocalStore` stays the app's read path. Firestore is a backup, not a
  dependency: pulls that fail return null and the local cache is used, so the
  app keeps working offline.

**Startup** (`lib/main.dart`)

- If the placeholders are still in place, Firebase is skipped entirely.
- If initialisation throws — no network on first run, bad config — it is caught
  and the app starts on local accounts. It never crashes into a config error.

## Verifying it works

1. `flutter run`, sign up with an email, earn some XP.
2. Check **Firestore → Data**: a `users/{uid}` document should appear within
   about five seconds, with your XP in it.
3. Uninstall the app, reinstall, log in with the same email. The XP and streak
   should come back. **This is the test that matters** — it is the whole reason
   the sync exists.
4. Sign out and back in with Google. If it fails with
   `ApiException: 10`, the SHA-1 fingerprint is missing or wrong (section 2).

## Not yet done

- **No account-linking UI.** A guest who later signs up with Google gets a new
  account rather than upgrading the anonymous one; their guest progress stays
  behind. `FirebaseAuth.currentUser.linkWithCredential()` is the fix.
- **No merge strategy.** If the same account is used on two devices at once,
  the last write wins and the other device's progress in that window is lost.
  The `updatedAt` server timestamp is already written to support a smarter
  merge later.
- **None of this has been run against a real Firebase project**, because that
  needs credentials and an Android build. Work through the verification steps
  above before trusting it.
