import 'dart:math';

import '../models/user_profile.dart';
import 'local_store.dart';

/// Sign-in methods offered on the auth screen.
enum AuthMethod { google, apple, email, guest }

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contract the app codes against.
///
/// The UI never imports a concrete implementation, so swapping
/// [LocalAuthRepository] for a Firebase-backed one is a single-line change in
/// `authRepositoryProvider` — see `docs/FIREBASE_SETUP.md`.
abstract interface class AuthRepository {
  /// The signed-in user, or null.
  Future<UserProfile?> currentUser();

  /// [isSignUp] distinguishes "create an account" from "log in" for the email
  /// method. It matters to a real backend — creating an account that already
  /// exists and logging into one that does not are different errors, and
  /// guessing which the learner meant produces baffling messages.
  Future<UserProfile> signIn({
    required AuthMethod method,
    String? email,
    String? password,
    String? name,
    bool isSignUp = false,
  });

  Future<void> signOut();

  /// Emails a password-reset link. Throws [AuthException] with something the
  /// learner can act on when that is not possible.
  Future<void> sendPasswordReset(String email);

  /// Removes the account and every trace of its data.
  Future<void> deleteAccount();
}

/// Device-local authentication.
///
/// This is a real, working implementation — credentials are validated for
/// shape and the session persists across launches — but it authenticates
/// against the device only. It exists so the app runs end to end with no
/// backend configured; wire in Firebase before shipping to production.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  final LocalStore _store;

  @override
  Future<UserProfile?> currentUser() async {
    if (!_store.getBool(LocalStore.kSignedIn)) return null;
    final json = _store.getJson(LocalStore.kProfile);
    if (json == null) return null;
    return UserProfile.fromJson(json);
  }

  @override
  Future<UserProfile> signIn({
    required AuthMethod method,
    String? email,
    String? password,
    String? name,
    bool isSignUp = false,
  }) async {
    // Simulates the round trip so loading states are exercised in development
    // exactly as they will be against a real backend.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    switch (method) {
      case AuthMethod.email:
        final address = (email ?? '').trim();
        if (!_looksLikeEmail(address)) {
          throw const AuthException('Please enter a valid email address.');
        }
        if ((password ?? '').length < 6) {
          throw const AuthException(
            'Password must be at least 6 characters.',
          );
        }
        return _persist(
          UserProfile.initial(
            id: 'local_${address.hashCode.toRadixString(16)}',
            name: name?.trim().isNotEmpty == true
                ? name!.trim()
                : _nameFromEmail(address),
            email: address,
          ),
        );

      case AuthMethod.google:
      case AuthMethod.apple:
        throw AuthException(
          '${method == AuthMethod.google ? 'Google' : 'Apple'} sign-in needs '
          'Firebase to be configured. See docs/FIREBASE_SETUP.md — or '
          'continue as a guest for now.',
        );

      case AuthMethod.guest:
        return _persist(
          UserProfile.initial(
            id: 'guest_${Random().nextInt(1 << 32).toRadixString(16)}',
            name: name?.trim().isNotEmpty == true ? name!.trim() : 'Learner',
            isGuest: true,
          ),
        );
    }
  }

  @override
  Future<void> signOut() async {
    await _store.setBool(LocalStore.kSignedIn, false);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // There is no server to send from: this account exists only on this phone.
    throw const AuthException(
      'Password reset needs an online account. This device is storing your '
      'progress locally, so there is no password to reset — sign in again '
      'with any password of 6 characters or more.',
    );
  }

  @override
  Future<void> deleteAccount() async {
    await _store.clearAll();
  }

  Future<UserProfile> _persist(UserProfile profile) async {
    // Preserve progress if this device already has a profile for the account.
    final existing = _store.getJson(LocalStore.kProfile);
    final result = existing != null &&
            UserProfile.fromJson(existing).id == profile.id
        ? UserProfile.fromJson(existing)
        : profile;

    await _store.setJson(LocalStore.kProfile, result.toJson());
    await _store.setBool(LocalStore.kSignedIn, true);
    return result;
  }

  static bool _looksLikeEmail(String v) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v);

  static String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    return local
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
