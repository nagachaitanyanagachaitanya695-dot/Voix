import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/local_store.dart';
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

/// Swap this override to move authentication to Firebase — nothing else in
/// the app references a concrete implementation.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => LocalAuthRepository(ref.watch(localStoreProvider)),
);

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
