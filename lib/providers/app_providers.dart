import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/local_store.dart';
import '../data/repositories/profile_sync.dart';
import '../data/services/ai_tutor_service.dart';
import '../data/services/notification_service.dart';
import '../data/services/speech_service.dart';

/// Injected in `main()` once [LocalStore.open] resolves, so the rest of the
/// tree can read storage synchronously and the first frame renders with real
/// data rather than a loading flash.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError(
    'localStoreProvider must be overridden in ProviderScope',
  ),
);

/// Whether `Firebase.initializeApp` succeeded during startup.
///
/// Overridden in `main()`. It is false both when the project is unconfigured
/// (the placeholders in `firebase_options.dart` are still in place) and when
/// initialisation failed on the device — the app has to behave identically in
/// either case, which is why this is one flag rather than two.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Real accounts when Firebase is available, device-local accounts when it is
/// not. Nothing else in the app references a concrete implementation.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final store = ref.watch(localStoreProvider);
  if (!ref.watch(firebaseReadyProvider)) return LocalAuthRepository(store);
  return FirebaseAuthRepository(
    auth: FirebaseAuth.instance,
    store: store,
    sync: ref.watch(profileSyncProvider),
  );
});

/// Backs the profile up to Firestore, or does nothing when Firebase is off.
final profileSyncProvider = Provider<ProfileSync>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return const NoOpProfileSync();
  final sync = FirestoreProfileSync(FirebaseFirestore.instance);
  ref.onDispose(sync.dispose);
  return sync;
});

/// Likewise: point this at a hosted LLM client to upgrade the tutor.
final aiTutorProvider = Provider<AiTutorService>(
  (ref) => LocalAiTutorService(),
);

/// Schedules the daily reminders. Kept alive for the process lifetime so the
/// timezone database and the notification channel are only set up once.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService();
  ref.onDispose(service.dispose);
  return service;
});

/// Light / dark / follow-system, persisted across launches.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final raw = ref.read(localStoreProvider).getString(LocalStore.kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark, // Dark is the designed default.
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(localStoreProvider).setString(
          LocalStore.kThemeMode,
          mode.name,
        );
  }

  Future<void> toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

/// Whether the learner has finished onboarding. Kept separate from sign-in so
/// a returning user who signs out does not repeat the questionnaire.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() => ref.read(localStoreProvider).getBool(LocalStore.kOnboarded);

  Future<void> complete() async {
    state = true;
    await ref.read(localStoreProvider).setBool(LocalStore.kOnboarded, true);
  }

  Future<void> reset() async {
    state = false;
    await ref.read(localStoreProvider).setBool(LocalStore.kOnboarded, false);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
