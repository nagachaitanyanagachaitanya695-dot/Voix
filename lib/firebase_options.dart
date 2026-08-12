import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase project configuration.
///
/// **This file ships with placeholders and Firebase is therefore switched
/// off.** The app runs perfectly well like that — accounts are stored on the
/// device by `LocalAuthRepository` — but progress lives only on that device
/// and a reinstall loses it.
///
/// To turn Firebase on, either:
///
///   1. Run `flutterfire configure`, which overwrites this file with your real
///      project's values (the usual route), or
///   2. Copy the values out of the Firebase console into the constants below.
///
/// Either way [isConfigured] flips to true and `main()` starts initialising
/// Firebase. Nothing else in the app needs to change: the provider in
/// `app_providers.dart` picks the Firebase repository automatically.
///
/// See `docs/FIREBASE_SETUP.md` for the console side — creating the project,
/// enabling the sign-in providers, registering the SHA-1 fingerprint that
/// Google Sign-In needs, and the Firestore security rules.
///
/// > These values are **not** secrets. A Firebase `apiKey` identifies the
/// > project; it does not authorise anything on its own. What protects your
/// > data is the Firestore security rules, which is why the rules in
/// > `docs/FIREBASE_SETUP.md` are not optional.
abstract final class DefaultFirebaseOptions {
  /// Whether real project values have been filled in.
  ///
  /// Checked before `Firebase.initializeApp` so an unconfigured build fails
  /// over to local accounts instead of crashing on the first frame.
  static bool get isConfigured => !_android.apiKey.startsWith(_placeholder);

  static const _placeholder = 'REPLACE_ME';

  static FirebaseOptions get currentPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.android => _android,
        TargetPlatform.iOS => _ios,
        _ => throw UnsupportedError(
            'Voix currently targets Android and iOS only. Run '
            '`flutterfire configure` to add another platform.',
          ),
      };

  static const _android = FirebaseOptions(
    apiKey: 'REPLACE_ME_ANDROID_API_KEY',
    appId: 'REPLACE_ME_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    storageBucket: 'REPLACE_ME_PROJECT_ID.appspot.com',
  );

  static const _ios = FirebaseOptions(
    apiKey: 'REPLACE_ME_IOS_API_KEY',
    appId: 'REPLACE_ME_IOS_APP_ID',
    messagingSenderId: 'REPLACE_ME_SENDER_ID',
    projectId: 'REPLACE_ME_PROJECT_ID',
    storageBucket: 'REPLACE_ME_PROJECT_ID.appspot.com',
    iosBundleId: 'com.voix.voix',
  );

  /// The OAuth **web** client id from the Firebase console, needed by
  /// Google Sign-In on Android — the Android client alone is not enough,
  /// because the token Firebase verifies is issued to the web client.
  ///
  /// Found under Project settings › General › Your apps, or in
  /// `google-services.json` as the `client_type: 3` entry.
  static const googleServerClientId = 'REPLACE_ME_WEB_CLIENT_ID';

  static bool get hasGoogleClientId =>
      !googleServerClientId.startsWith(_placeholder);
}
