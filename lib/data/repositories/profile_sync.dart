import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

/// Backs the learner's profile up off the device.
///
/// The app does not read from this on the hot path — `LocalStore` remains the
/// single source of truth, so everything keeps working on a train with no
/// signal. This exists for the two moments that matter: restoring progress
/// after a reinstall or on a second device, and not losing a year of streaks
/// to a dropped phone.
abstract interface class ProfileSync {
  /// The stored profile for [userId], or null if the account is new or the
  /// fetch failed. Never throws — a failed restore falls back to local data.
  Future<UserProfile?> pull(String userId);

  /// Queues [profile] to be written. Returns immediately; the write happens in
  /// the background and is coalesced with any others that arrive shortly after.
  void push(UserProfile profile);

  /// Writes anything still queued. Called before sign-out so the last session
  /// is not lost.
  Future<void> flush();

  Future<void> delete(String userId);

  void dispose();
}

/// Used when Firebase is not configured: the profile simply stays on-device.
class NoOpProfileSync implements ProfileSync {
  const NoOpProfileSync();

  @override
  Future<UserProfile?> pull(String userId) async => null;

  @override
  void push(UserProfile profile) {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> delete(String userId) async {}

  @override
  void dispose() {}
}

/// Mirrors the profile into Firestore at `users/{uid}`.
class FirestoreProfileSync implements ProfileSync {
  FirestoreProfileSync(this._db);

  final FirebaseFirestore _db;

  /// Progress changes on nearly every interaction — each answered quiz
  /// question moves XP. Writing straight through would bill a document write
  /// per tap and drain the battery on mobile data, so writes are coalesced
  /// into one every few seconds.
  static const _debounce = Duration(seconds: 5);

  Timer? _timer;
  UserProfile? _pending;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<UserProfile?> pull(String userId) async {
    try {
      final snap = await _users.doc(userId).get();
      final data = snap.data();
      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (e) {
      debugPrint('ProfileSync: pull failed ($e)');
      return null;
    }
  }

  @override
  void push(UserProfile profile) {
    _pending = profile;
    _timer ??= Timer(_debounce, () {
      _timer = null;
      unawaited(flush());
    });
  }

  @override
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final profile = _pending;
    if (profile == null) return;
    _pending = null;

    try {
      await _users.doc(profile.id).set({
        ...profile.toJson(),
        // Server time, so it stays meaningful when a device's clock is wrong —
        // and it is what a future last-writer-wins merge would compare.
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // A failed backup must not surface as an error in the UI: the profile is
      // already safe in local storage, and the next push will retry.
      debugPrint('ProfileSync: push failed ($e)');
    }
  }

  @override
  Future<void> delete(String userId) async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    try {
      await _users.doc(userId).delete();
    } catch (e) {
      debugPrint('ProfileSync: delete failed ($e)');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
