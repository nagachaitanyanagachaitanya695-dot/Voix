import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/data/services/notification_service.dart';
import 'package:voix/features/profile/notifications_screen.dart';
import 'package:voix/providers/app_providers.dart';
import 'package:voix/providers/user_controller.dart';

/// Stands in for the platform plugin, recording what it was asked to do.
class _StubNotifications extends NotificationService {
  final syncs = <UserProfile>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sync(UserProfile user, {bool prompt = false}) async {
    syncs.add(user);
  }

  @override
  Future<void> cancelAll() async {}
}

/// The three reminder switches used to be bound to a single field, so turning
/// one off turned all three off. These tests hold them independent.
void main() {
  const learner = UserProfile(
    id: 'u1',
    name: 'Hrithik',
    currentStreak: 12,
    dailyGoalMinutes: 20,
  );

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2400);
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
        // These tests are about the switches and what they persist. The real
        // service talks to platform channels that no test host answers, and
        // its timeouts would leave timers pending past the end of the test.
        // Its own behaviour is covered by notification_service_test.dart.
        notificationServiceProvider.overrideWithValue(_StubNotifications()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: const NotificationsScreen(),
        ),
      ),
    );
    // See app_smoke_test for why this is repeated pumps, not pumpAndSettle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    return container;
  }

  Switch switchFor(WidgetTester tester, String title) {
    final tile = find.ancestor(
      of: find.text(title),
      matching: find.byType(Row),
    );
    return tester.widget<Switch>(
      find.descendant(of: tile.first, matching: find.byType(Switch)),
    );
  }

  testWidgets('renders all three reminder switches', (tester) async {
    await pump(tester);
    expect(find.text('Practice Reminders'), findsOneWidget);
    expect(find.text('Daily Goal Updates'), findsOneWidget);
    expect(find.text('Streak Alerts'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));
  });

  testWidgets('each switch reflects its own field', (tester) async {
    await pump(tester);
    for (final title in [
      'Practice Reminders',
      'Daily Goal Updates',
      'Streak Alerts',
    ]) {
      expect(switchFor(tester, title).value, isTrue, reason: title);
    }
  });

  testWidgets('turning one off leaves the other two on', (tester) async {
    final container = await pump(tester);

    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Daily Goal Updates'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final user = container.read(userControllerProvider)!;
    expect(user.goalUpdatesEnabled, isFalse);
    expect(user.remindersEnabled, isTrue);
    expect(user.streakAlertsEnabled, isTrue);
  });

  testWidgets('the preference survives a reload', (tester) async {
    final container = await pump(tester);
    await container
        .read(userControllerProvider.notifier)
        .setReminderPreference(
          (u) => u.copyWith(streakAlertsEnabled: false),
          prompting: false,
        );

    // Read it back through a fresh controller, the way a relaunch would.
    final store = await LocalStore.open();
    final stored = UserProfile.fromJson(store.getJson(LocalStore.kProfile)!);
    expect(stored.streakAlertsEnabled, isFalse);
    expect(stored.remindersEnabled, isTrue);
  });

  testWidgets('shows the reminder time and does not overflow', (tester) async {
    await pump(tester);
    expect(find.text('Reminder Time'), findsOneWidget);
    // 19:00 is the default; formatted per locale by TimeOfDay.format.
    expect(find.textContaining('7:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
