import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/onboarding/onboarding_flow.dart';
import 'package:voix/features/shell/app_shell.dart';
import 'package:voix/features/splash/splash_screen.dart';
import 'package:voix/providers/app_providers.dart';

/// The splash is the only thing between launch and the app. If it ever fails
/// to hand over, the app is simply broken — there is no way past it, no error
/// to report, and nothing to tap.
void main() {
  const learner = UserProfile(id: 'u1', name: 'Chaitanya');

  Future<ProviderContainer> containerWith({required bool onboarded}) async {
    SharedPreferences.setMockInitialValues({
      LocalStore.kOnboarded: onboarded,
      LocalStore.kSignedIn: onboarded,
      if (onboarded) LocalStore.kProfile: jsonEncode(learner.toJson()),
    });
    return ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(await LocalStore.open()),
        firebaseReadyProvider.overrideWithValue(false),
      ],
    );
  }

  Future<void> pumpSplash(WidgetTester tester, ProviderContainer c) async {
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: const SplashScreen(),
        ),
      ),
    );
  }

  /// Pumps in small steps until the splash is gone, up to [budget].
  ///
  /// Not a fixed pump: a ticker's first frame carries zero elapsed time, so
  /// the sequence finishes a frame or two later than its nominal duration and
  /// a single pump of exactly that length lands short. Waiting for the
  /// condition tests what actually matters — that it hands over at all.
  Future<bool> pumpUntilHandedOver(
    WidgetTester tester, {
    Duration budget = const Duration(seconds: 6),
  }) async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < budget; waited += step) {
      await tester.pump(step);
      if (find.byType(SplashScreen).evaluate().isEmpty) {
        // One more frame so the incoming route has built.
        await tester.pump(const Duration(milliseconds: 300));
        return true;
      }
    }
    return false;
  }

  testWidgets('hands over to the app once the sequence finishes',
      (tester) async {
    await pumpSplash(tester, await containerWith(onboarded: true));

    expect(find.byType(AppShell), findsNothing);

    expect(await pumpUntilHandedOver(tester), isTrue);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('hands over even if the animation never reports completion',
      (tester) async {
    // A ticker is muted while the app is not visible, so a controller that was
    // running when someone switched away never reports completion and its
    // status listener never fires. Before the failsafe, that left the splash on
    // screen permanently — a frozen app with no way forward.
    final c = await containerWith(onboarded: true);
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: const TickerMode(enabled: false, child: SplashScreen()),
        ),
      ),
    );

    // Well past the sequence, and still nothing has moved — which is exactly
    // the state a user would be stranded in.
    await tester.pump(const Duration(milliseconds: 2800));
    expect(
      find.byType(SplashScreen),
      findsOneWidget,
      reason: 'a muted ticker cannot have completed the sequence',
    );

    // The failsafe fires a second after the sequence should have ended.
    expect(await pumpUntilHandedOver(tester), isTrue);
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('a first-time user lands in onboarding, not the app',
      (tester) async {
    await pumpSplash(tester, await containerWith(onboarded: false));

    expect(await pumpUntilHandedOver(tester), isTrue);

    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  testWidgets('the handover is quick', (tester) async {
    // A route ignores hit tests until its transition completes, so a long
    // transition is time the app is visible and unresponsive — which is
    // indistinguishable from a hang. 260ms plus a frame should be enough.
    await pumpSplash(tester, await containerWith(onboarded: true));
    expect(await pumpUntilHandedOver(tester), isTrue);

    final route = ModalRoute.of(tester.element(find.byType(AppShell)))!;
    expect(
      route.animation?.status,
      AnimationStatus.completed,
      reason: 'until this completes the app is on screen but ignoring taps',
    );
  });
}
