import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/home/home_screen.dart';
import 'package:voix/features/learn/learn_screen.dart';
import 'package:voix/features/onboarding/onboarding_flow.dart';
import 'package:voix/features/practice/practice_screen.dart';
import 'package:voix/features/profile/profile_screen.dart';
import 'package:voix/features/progress/progress_screen.dart';
import 'package:voix/features/shell/app_shell.dart';
import 'package:voix/providers/app_providers.dart';
import 'package:voix/providers/user_controller.dart';

/// Builds a real provider scope backed by an in-memory SharedPreferences,
/// optionally pre-seeded with a signed-in learner.
Future<ProviderContainer> _container({UserProfile? user}) async {
  SharedPreferences.setMockInitialValues({
    if (user != null) ...{
      LocalStore.kSignedIn: true,
      LocalStore.kProfile: _encode(user),
      LocalStore.kOnboarded: true,
    },
  });
  final store = await LocalStore.open();
  return ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );
}

String _encode(UserProfile user) => jsonEncode(user.toJson());

/// Advances the staggered entrance animations to completion.
///
/// `pumpAndSettle` is not usable here: the aurora backdrop and the energy orb
/// repeat forever by design, so the tree never quiesces. A single large pump
/// is not enough either — `FadeSlideIn` starts its controller from a stagger
/// Timer, so one pump fires the timer but the controller's ticker only
/// advances on the *following* frame, leaving content transparent and offset.
/// Repeated small pumps fire the timers and then tick the controllers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Gives the test a tall phone-shaped surface.
///
/// The default 800x600 window is shorter than any real device, so lazily-built
/// list items below the fold never get created and `find.text` misses them.
void _setSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(420, 2400);
  addTearDown(tester.view.reset);
}

/// Wraps a screen in the app's theme plus a provider scope.
Widget _host(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: VoixTheme.dark(),
      darkTheme: VoixTheme.dark(),
      // Tab screens are hosted by AppShell's Scaffold in the real app.
      home: child is AppShell ? child : Scaffold(body: child),
    ),
  );
}

const _seeded = UserProfile(
  id: 'test',
  name: 'Hrithik Kumar',
  email: 'h@example.com',
  xp: 1250,
  currentStreak: 12,
  longestStreak: 12,
  dailyGoalMinutes: 20,
  minutesToday: 15,
  totalConversations: 32,
  totalMinutes: 865,
  wordsLearned: 45,
);

void main() {
  testWidgets('onboarding renders and advances past the welcome step',
      (tester) async {
    _setSurface(tester);
    final container = await _container();
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, const OnboardingFlow()));
    await _settle(tester);

    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await _settle(tester);

    expect(find.text("What's your name?"), findsOneWidget);
  });

  testWidgets('home renders the learner dashboard', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);
    expect(container.read(userControllerProvider), isNotNull);

    await tester.pumpWidget(_host(container, const HomeScreen()));
    await _settle(tester);

    expect(find.textContaining('Hi, Hrithik'), findsOneWidget);
    expect(find.text('Continue Learning'), findsOneWidget);
    expect(find.text('Quick Access'), findsOneWidget);
  });

  testWidgets('progress renders lifetime stats', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, const ProgressScreen()));
    await _settle(tester);

    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Weekly Activity'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
  });

  testWidgets('learn lists lessons and filters by category', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, const LearnScreen()));
    await _settle(tester);

    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Present Simple Basics'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filter_grammar')));
    await _settle(tester);

    // Grammar survives the filter; a vocabulary lesson does not.
    expect(find.text('Present Simple Basics'), findsOneWidget);
    expect(find.text('Say It Stronger'), findsNothing);
  });

  testWidgets('practice renders both modes', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, const PracticeScreen()));
    await _settle(tester);

    expect(find.text('Choose Mode'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Gen-Z'), findsOneWidget);
    expect(find.text('Tap to Start Speaking'), findsOneWidget);
  });

  testWidgets('profile renders preferences and account groups', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, const ProfileScreen()));
    await _settle(tester);

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('AI Tutor Voice'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('nav bar clears the system gesture bar', (tester) async {
    // Reported from a real phone: the bottom half of every nav icon was
    // hidden underneath the gesture pill. The scaffold sets extendBody, so
    // the bar draws over the system inset and has to add it back in full —
    // a fixed padding token is not enough on a gesture-navigation device.
    _setSurface(tester);
    const inset = 48.0;
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: inset),
          size: Size(420, 2400),
        ),
        child: _host(container, const AppShell()),
      ),
    );
    await _settle(tester);

    final padding =
        tester.widget<Padding>(find.byKey(navBarPaddingKey)).padding.resolve(
              TextDirection.ltr,
            );
    expect(
      padding.bottom,
      greaterThanOrEqualTo(inset),
      reason: 'the bar must sit above the gesture area, not under it',
    );
  });

  testWidgets('shell switches tabs without rebuilding state', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, const AppShell()));
    await _settle(tester);

    expect(find.textContaining('Hi, Hrithik'), findsOneWidget);

    // Four tabs, matching the design — lessons are reached from the Practice
    // grid and from Home, not from the bar. Asserted on the stack rather than
    // on label text, because Home has its own "Learn" shortcut tile.
    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.children, hasLength(4));

    await tester.tap(find.text('Practice').last);
    await _settle(tester);
    expect(find.text('Choose Mode'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await _settle(tester);
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('light theme builds without overflow', (tester) async {
    _setSurface(tester);
    final container = await _container(user: _seeded);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VoixTheme.light(),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Hi, Hrithik'), findsOneWidget);
  });
}
