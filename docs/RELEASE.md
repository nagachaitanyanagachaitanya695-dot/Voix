# Shipping Voix to Google Play

Everything here needs a machine with the Android SDK installed. None of it can
be done from a CI container without one.

---

## 1. Create the upload keystore

You sign every release with the same key forever. **If you lose it you cannot
update the app** — you would have to publish a new listing under a new package
name and abandon your existing users. Back it up somewhere you will still have
access to in five years.

```bash
keytool -genkey -v \
  -keystore ~/voix-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias voix
```

`keytool` ships with the JDK. It asks for a store password, a key password, and
your name/organisation — the identity fields are cosmetic and never shown to
users, but the passwords are not recoverable.

> Keep the keystore **outside** the repository. The path below points at your
> home directory for exactly that reason.

## 2. Point the build at it

Create `android/key.properties`:

```properties
storePassword=<the store password you just chose>
keyPassword=<the key password you just chose>
keyAlias=voix
storeFile=/home/you/voix-upload-key.jks
```

`android/.gitignore` already excludes `key.properties`, `*.jks` and
`*.keystore`, so none of this can be committed by accident.

> **`android/test-signing.jks` is the one exception**, and it is not yours. It
> is a throwaway key that CI signs test builds with, so that each APK from a
> build can be installed over the last one — Android refuses to update an app
> whose signing key changed, which is what "App not installed" usually means.
> Its password is in the workflow file. It is not an upload key and Play will
> reject anything signed with it. Do not use it for a release, and do not
> confuse it with the keystore you create above.

`android/app/build.gradle.kts` reads the file if it exists and signs the release
build with it. If the file is missing, the release build falls back to debug
keys — useful for `flutter run --release`, and harmless, because Play rejects a
debug-signed upload at the door.

## 3. Build the bundle

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`. That is the file you
upload. (`flutter build apk` produces an APK for sideloading and testing; Play
itself wants the `.aab`.)

Verify it really is signed with your key, not the debug key:

```bash
jarsigner -verify -verbose -certs \
  build/app/outputs/bundle/release/app-release.aab | head -20
```

The certificate owner should be the identity you entered in step 1 — if it says
`CN=Android Debug`, `key.properties` was not found.

## 4. Version for each upload

Play refuses an upload whose `versionCode` it has already seen. Bump the number
after the `+` in `pubspec.yaml` every single time:

```yaml
version: 1.0.0+1   # 1.0.0 is shown to users, 1 is the versionCode
```

`1.0.1+2`, `1.1.0+3`, and so on.

---

## Still outstanding before you can submit

- [ ] **Build the app at least once.** It has never been compiled for Android —
      only analysed and unit-tested. Run `flutter build appbundle --release` and
      fix whatever Gradle says before anything else.
- [ ] **Test the microphone and the voice on a real phone.** They have never run
      on hardware. This is the app's core feature.
- [ ] **Host a privacy policy and link it in the Play Console.** Mandatory,
      because the app requests `RECORD_AUDIO`. A drafted policy is in
      `docs/PRIVACY_POLICY.md` — fill in the bracketed placeholders, host it
      (GitHub Pages instructions are at the bottom of that file), and paste the
      URL into Play Console → App content.
- [ ] **Fill in the Data Safety form.** It has to match the privacy policy or
      the submission is rejected. `docs/PRIVACY_POLICY.md` ends with a
      question-by-question table for it.
- [ ] **Configure Firebase**, or ship knowing that accounts are device-local and
      a reinstall wipes all progress. See `docs/FIREBASE_SETUP.md`.
- [ ] Store listing assets: the 512×512 icon is generated at
      `store/play_icon_512.png`; you still need a 1024×500 feature graphic and
      at least two phone screenshots.

## Regenerating the launcher icon

The launcher icons are generated from the same `VoixLogo` painter the app draws
on screen, so they cannot drift from the brand mark:

```bash
flutter test test/generate_launcher_icons.dart --tags icons
```

This rewrites every `mipmap-*/ic_launcher*.png` and `store/play_icon_512.png`.
