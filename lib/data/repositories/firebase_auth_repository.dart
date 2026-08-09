import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';
import 'local_store.dart';
import 'profile_sync.dart';

/// Real accounts, backed by Firebase Authentication.
///
/// Every method still writes through to [LocalStore]. That is deliberate: the
/// rest of the app reads the profile synchronously from local storage, so
/// keeping the cache authoritative means signing in works offline for a
/// returning user and the first frame after launch never waits on a network
/// round trip. Firestore is the backup, not the read path.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required fb.FirebaseAuth auth,
    required LocalStore store,
    required ProfileSync sync,
  })  : _auth = auth,
        _store = store,
        _sync = sync;

  final fb.FirebaseAuth _auth;
  final LocalStore _store;
  final ProfileSync _sync;

  bool _googleReady = false;

  @override
  Future<UserProfile?> currentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Firebase is the authority on whether a session exists. If it says no,
      // a stale local "signed in" flag must not resurrect the account.
      if (_store.getBool(LocalStore.kSignedIn)) {
        await _store.setBool(LocalStore.kSignedIn, false);
      }
      return null;
    }

    final cached = _store.getJson(LocalStore.kProfile);
    if (cached != null) {
      final profile = UserProfile.fromJson(cached);
      if (profile.id == user.uid) return profile;
    }

    // Signed in to Firebase but nothing cached: a reinstall, or a second
    // device. This is the case the whole sync exists for.
    return _restore(user);
  }

  @override
  Future<UserProfile> signIn({
    required AuthMethod method,
    String? email,
    String? password,
    String? name,
    bool isSignUp = false,
  }) async {
    try {
      final credential = switch (method) {
        AuthMethod.email => await _email(
            email: (email ?? '').trim(),
            password: password ?? '',
            name: name,
            isSignUp: isSignUp,
          ),
        AuthMethod.google => await _google(),
        AuthMethod.apple => await _apple(),
        AuthMethod.guest => await _auth.signInAnonymously(),
      };

      final user = credential.user;
      if (user == null) {
        throw const AuthException('Sign-in did not complete. Please try again.');
      }
      return _restore(
        user,
        fallbackName: name,
        isGuest: method == AuthMethod.guest,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> signOut() async {
    // Push the final state before the credentials that authorise the write go
    // away, or the last session's progress never reaches the cloud.
    await _sync.flush();
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('FirebaseAuthRepository: Google sign-out failed ($e)');
    }
    await _auth.signOut();
    await _store.setBool(LocalStore.kSignedIn, false);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final address = email.trim();
    if (address.isEmpty) {
      throw const AuthException('Enter your email address first.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: address);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _sync.delete(user.uid);
      try {
        await user.delete();
      } on fb.FirebaseAuthException catch (e) {
        // Firebase requires a recent login before it will delete an account.
        if (e.code == 'requires-recent-login') {
          throw const AuthException(
            'For your security, please sign in again before deleting your '
            'account.',
          );
        }
        throw AuthException(_message(e));
      }
    }
    await _store.clearAll();
  }

  // ── Methods ────────────────────────────────────────────────────────────

  Future<fb.UserCredential> _email({
    required String email,
    required String password,
    required String? name,
    required bool isSignUp,
  }) async {
    if (!isSignUp) {
      return _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await credential.user?.updateDisplayName(trimmed);
    }
    return credential;
  }

  Future<fb.UserCredential> _google() async {
    if (!DefaultFirebaseOptions.hasGoogleClientId) {
      throw const AuthException(
        'Google sign-in is not configured for this build yet.',
      );
    }

    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        serverClientId: DefaultFirebaseOptions.googleServerClientId,
      );
      _googleReady = true;
    }

    if (!google.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in is not available on this device.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Google sign-in was cancelled.');
      }
      throw AuthException('Google sign-in failed: ${e.code.name}.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
        'Google did not return a sign-in token. Please try again.',
      );
    }

    return _auth.signInWithCredential(
      fb.GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<fb.UserCredential> _apple() async {
    // Android has no native Apple sign-in, so this goes through Firebase's
    // hosted web flow. On iOS the same call uses the native sheet.
    final provider = fb.OAuthProvider('apple.com')
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(provider);
  }

  // ── Profile ────────────────────────────────────────────────────────────

  /// Produces the profile to hand back to the app, preferring — in order — the
  /// cloud copy, the local cache, then a fresh profile.
  Future<UserProfile> _restore(
    fb.User user, {
    String? fallbackName,
    bool isGuest = false,
  }) async {
    final remote = await _sync.pull(user.uid);

    final cachedJson = _store.getJson(LocalStore.kProfile);
    final cached = cachedJson == null ? null : UserProfile.fromJson(cachedJson);

    var profile = remote ??
        (cached != null && cached.id == user.uid ? cached : null) ??
        UserProfile.initial(
          id: user.uid,
          name: _name(user, fallbackName),
          email: user.email,
          isGuest: isGuest,
        );

    // Identity always comes from the provider — a display name or photo the
    // learner changed with Google should win over whatever was cached.
    profile = profile.copyWith(
      id: user.uid,
      name: profile.name.isEmpty ? _name(user, fallbackName) : profile.name,
      email: user.email ?? profile.email,
      photoUrl: user.photoURL ?? profile.photoUrl,
      isGuest: user.isAnonymous,
    );

    await _store.setJson(LocalStore.kProfile, profile.toJson());
    await _store.setBool(LocalStore.kSignedIn, true);
    _sync.push(profile);
    return profile;
  }

  static String _name(fb.User user, String? fallback) {
    final candidates = [
      user.displayName,
      fallback,
      user.email?.split('@').first,
    ];
    for (final c in candidates) {
      final v = c?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return 'Learner';
  }

  /// Firebase's error codes are precise but unreadable. These are the ones a
  /// learner can actually act on.
  static String _message(fb.FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address does not look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' || 'invalid-credential' || 'wrong-password' =>
          'Wrong email or password. If you are new here, tap Sign up.',
        'email-already-in-use' =>
          'An account already exists for that email. Try logging in instead.',
        'weak-password' => 'Please choose a password of at least 6 characters.',
        'operation-not-allowed' =>
          'That sign-in method is not enabled for this app yet.',
        'too-many-requests' =>
          'Too many attempts. Please wait a moment and try again.',
        'network-request-failed' =>
          'No internet connection. Please check your network and try again.',
        'account-exists-with-different-credential' =>
          'You already have an account with this email using a different '
              'sign-in method.',
        _ => 'Sign-in failed. Please try again.',
      };
}
