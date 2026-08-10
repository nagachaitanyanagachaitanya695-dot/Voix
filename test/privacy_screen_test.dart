import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/profile/privacy_screen.dart';
import 'package:voix/providers/app_providers.dart';

/// The Data Usage sheet is a privacy disclosure, so two things have to hold:
/// it must describe what this particular build actually does, and it must never
/// clip — a truncated disclosure is a misleading one.
void main() {
  const learner = UserProfile(id: 'u1', name: 'Hrithik');

  Future<void> openSheet(
    WidgetTester tester, {
    required bool firebaseReady,
    double textScale = 1.0,
    Size surface = const Size(360, 640),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surface;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      LocalStore.kSignedIn: true,
      LocalStore.kOnboarded: true,
      LocalStore.kProfile: jsonEncode(learner.toJson()),
    });
    final store = await LocalStore.open();
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const PrivacyScreen(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    // At a large text scale the tile sits below the fold, and tapping a
    // widget that is not on screen silently misses.
    final tile = find.text('Data Usage').first;
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('without a backend it says data stays on the device',
      (tester) async {
    await openSheet(tester, firebaseReady: false);

    expect(find.textContaining('stay on this device'), findsOneWidget);
    expect(find.textContaining('backed up'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a backend it says data is backed up', (tester) async {
    await openSheet(tester, firebaseReady: true);

    expect(find.textContaining('backed up to your account'), findsWidgets);
    // The no-backend wording must not survive into a syncing build.
    expect(find.textContaining('stay on this device'), findsNothing);
    expect(find.textContaining('device only'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('is honest that the recogniser may send audio off-device',
      (tester) async {
    await openSheet(tester, firebaseReady: false);
    expect(find.textContaining('never records or stores audio'), findsOneWidget);
    // The part that is easy to leave out and matters most.
    expect(find.textContaining('send the audio to Google'), findsOneWidget);
  });

  testWidgets('does not clip on a small screen at large text scale',
      (tester) async {
    // A short phone plus the largest text scale Android offers is the worst
    // case for a fixed-height sheet, and the case that used to overflow.
    await openSheet(
      tester,
      firebaseReady: true,
      textScale: 2.0,
      surface: const Size(320, 560),
    );

    expect(tester.takeException(), isNull);
    // Scrollable, so the content below the fold is reachable rather than lost.
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
