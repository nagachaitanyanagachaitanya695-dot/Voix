# Firebase setup

Voix ships with a working device-local auth implementation so the app runs on a
fresh clone with no configuration. This document covers replacing it with
Firebase for real Google / Apple sign-in and cross-device sync.

The UI never imports a concrete repository, so this is a contained change:
`AuthRepository` is an interface with **one** wiring point.

---

## 1. Add the packages

```bash
flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in
flutter pub add sign_in_with_apple   # iOS/macOS only
```

## 2. Generate the platform config

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This writes `lib/firebase_options.dart` plus
`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.

**Do not commit those two files.** Add to `.gitignore`:

```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

Add the Gradle plugin in `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

…and in `android/settings.gradle.kts`:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

Google sign-in needs your signing certificate's SHA-1 registered in the
Firebase console — debug and release are different certificates, and omitting
the release one is the usual cause of "sign-in works in debug, fails in
production".

## 3. Initialise before `runApp`

In `lib/main.dart`, alongside the existing `LocalStore.open()`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## 4. Implement the repository

Create `lib/data/repositories/firebase_auth_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Future<UserProfile?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snap = await _doc(user.uid).get();
    return snap.exists
        ? UserProfile.fromJson(snap.data()!)
        : _seed(user, isGuest: user.isAnonymous);
  }

  @override
  Future<UserProfile> signIn({
    required AuthMethod method,
    String? email,
    String? password,
    String? name,
  }) async {
    try {
      final fb.UserCredential cred = switch (method) {
        AuthMethod.google => await _google(),
        AuthMethod.apple => throw const AuthException(
            'Apple sign-in requires sign_in_with_apple; see step 5.',
          ),
        AuthMethod.email => await _emailSignInOrUp(email!, password!),
        AuthMethod.guest => await _auth.signInAnonymously(),
      };

      final user = cred.user!;
      final snap = await _doc(user.uid).get();
      if (snap.exists) return UserProfile.fromJson(snap.data()!);
      return _seed(user, name: name, isGuest: method == AuthMethod.guest);
    } on fb.FirebaseAuthException catch (e) {
      // Surface something a learner can act on, not a raw error code.
      throw AuthException(switch (e.code) {
        'wrong-password' || 'invalid-credential' =>
          'That email and password do not match.',
        'email-already-in-use' =>
          'That email already has an account. Try logging in.',
        'weak-password' => 'Please choose a longer password.',
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        _ => 'Could not sign you in. Please try again.',
      });
    }
  }

  Future<fb.UserCredential> _google() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) throw const AuthException('Sign-in was cancelled.');
    final auth = await account.authentication;
    return _auth.signInWithCredential(
      fb.GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      ),
    );
  }

  Future<fb.UserCredential> _emailSignInOrUp(String e, String p) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: e, password: p);
    } on fb.FirebaseAuthException catch (err) {
      if (err.code == 'user-not-found') {
        return _auth.createUserWithEmailAndPassword(email: e, password: p);
      }
      rethrow;
    }
  }

  Future<UserProfile> _seed(
    fb.User user, {
    String? name,
    bool isGuest = false,
  }) async {
    final profile = UserProfile.initial(
      id: user.uid,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : (user.displayName ?? 'Learner'),
      email: user.email,
      isGuest: isGuest,
    );
    await _doc(user.uid).set(profile.toJson());
    return profile;
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _doc(user.uid).delete();
    await user.delete();
  }
}
```

## 5. Flip the wiring

In `lib/providers/app_providers.dart`:

```dart
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);
```

That is the entire integration. Nothing in `features/` changes.

For Apple sign-in, add `sign_in_with_apple`, enable the *Sign in with Apple*
capability in Xcode, and fill in the `AuthMethod.apple` branch above with the
same credential exchange.

---

## 6. Sync progress to Firestore

`UserController._persist` currently writes only to `LocalStore`. To mirror to
Firestore, extend it — keeping the local write **first** so the app stays
responsive and offline-capable:

```dart
Future<void> _persist(UserProfile p) async {
  state = p;
  await _store.setJson(LocalStore.kProfile, p.toJson());   // source of truth
  unawaited(ref.read(remoteSyncProvider).push(p));         // best effort
}
```

Do not make the UI await the network. A learner finishing a lesson on a train
should still see their XP.

### Security rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
      match /{sub=**} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

Ship these before your first real user. The default test-mode rules leave every
document world-readable.
