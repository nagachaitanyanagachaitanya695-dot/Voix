@Tags(['render'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/conversation.dart';
import 'package:voix/data/models/daily_activity.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/auth/auth_screen.dart';
import 'package:voix/features/home/home_screen.dart';
import 'package:voix/features/learn/learn_screen.dart';
import 'package:voix/features/onboarding/onboarding_flow.dart';
import 'package:voix/features/practice/practice_screen.dart';
import 'package:voix/features/profile/profile_screen.dart';
import 'package:voix/features/progress/progress_screen.dart';
import 'package:voix/features/shell/app_shell.dart';
import 'package:voix/providers/app_providers.dart';

/// Renders each screen to a PNG so the UI can be reviewed without a device.
///
/// Run with:  flutter test test/render_screens.dart --update-goldens
/// Output:    test/screens/*.png
///
/// This is a visual-review tool, not an assertion suite — it is excluded from
/// `flutter test` by the `render` tag so a font-rendering difference on another
/// machine can never fail CI.
void main() {
  setUpAll(() async {
    // The test harness registers neither the icon font nor an emoji font, so
    // without these every Icon and emoji renders as an empty box.
    const iconFont =
        '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    const emojiFont = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
    if (File(iconFont).existsSync()) {
      await _loadFont('MaterialIcons', [iconFont]);
    }
    if (File(emojiFont).existsSync()) {
      // Registered under the families Flutter falls back to for emoji.
      await _loadFont('Noto Color Emoji', [emojiFont]);
      await _loadFont('Apple Color Emoji', [emojiFont]);
    }

    // Tests use a placeholder font unless the real ones are registered, which
    // would make every screenshot unreadable.
    await _loadFont('PlusJakartaSans', [
      'assets/fonts/PlusJakartaSans-400.ttf',
      'assets/fonts/PlusJakartaSans-500.ttf',
      'assets/fonts/PlusJakartaSans-600.ttf',
      'assets/fonts/PlusJakartaSans-700.ttf',
      'assets/fonts/PlusJakartaSans-800.ttf',
    ]);
    await _loadFont('Manrope', [
      'assets/fonts/Manrope-500.ttf',
      'assets/fonts/Manrope-700.ttf',
      'assets/fonts/Manrope-800.ttf',
    ]);
  });

  for (final theme in [_Mode.dark, _Mode.light]) {
    group(theme.name, () {
      _shot('01_onboarding', theme, (_) => const OnboardingFlow(), seed: false);
      _shot('02_auth', theme, (_) => const AuthScreen(), seed: false);
      _shot('03_home', theme, (_) => const HomeScreen());
      _shot('04_learn', theme, (_) => const LearnScreen());
      _shot('05_practice', theme, (_) => const PracticeScreen());
      _shot('06_progress', theme, (_) => const ProgressScreen());
      _shot('07_profile', theme, (_) => const ProfileScreen());
      _shot('08_shell', theme, (_) => const AppShell(), scaffold: false);
    });
  }
}

enum _Mode { dark, light }

void _shot(
  String name,
  _Mode mode,
  Widget Function(BuildContext) build, {
  bool seed = true,
  bool scaffold = true,
}) {
  testWidgets('$name (${mode.name})', (tester) async {
    // A common mid-range Android viewport.
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      if (seed) ...{
        LocalStore.kSignedIn: true,
        LocalStore.kOnboarded: true,
        LocalStore.kProfile: jsonEncode(_learner.toJson()),
        LocalStore.kActivity: jsonEncode(_week),
        LocalStore.kSessions: jsonEncode(_sessions),
      },
    });

    final store = await LocalStore.open();
    final container = ProviderContainer(
      overrides: [localStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: mode == _Mode.dark ? VoixTheme.dark() : VoixTheme.light(),
          home: Builder(
            builder: (context) => scaffold
                ? Scaffold(body: build(context))
                : build(context),
          ),
        ),
      ),
    );

    // Let the staggered entrances finish (see app_smoke_test for why this is
    // repeated pumps rather than pumpAndSettle).
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screens/${mode.name}_$name.png'),
    );
  });
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

// ── Sample data ────────────────────────────────────────────────────────────
// Mirrors the numbers in the reference screenshots so the render is directly
// comparable to the design.

final _learner = UserProfile(
  id: 'demo',
  name: 'Hrithik Kumar',
  email: 'hrithik@example.com',
  xp: 1250,
  currentStreak: 12,
  longestStreak: 12,
  dailyGoalMinutes: 20,
  minutesToday: 15,
  totalConversations: 32,
  totalMinutes: 865,
  wordsLearned: 45,
  completedLessonIds: const {'g_present_simple', 'v_stronger_words'},
  lastActiveDate: DateTime.now(),
);

/// Monday-anchored week matching the reference chart (12/18/22/28/16/10/6).
final _week = () {
  const minutes = [12, 18, 22, 28, 16, 10, 6];
  final today = DailyActivity.normalise(DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      DailyActivity(
        date: monday.add(Duration(days: i)),
        minutes: minutes[i],
        xp: minutes[i] * 8,
        conversations: i.isEven ? 1 : 0,
      ).toJson(),
  ];
}();

final _sessions = [
  _session('restaurant', 'Ordering Food at a Restaurant', '☕', 12, 85, 0),
  _session('interview', 'Job Interview Practice', '💼', 10, 78, 2),
  _session('weekend', 'Talking About My Weekend', '✈️', 8, 82, 26),
];

Map<String, dynamic> _session(
  String id,
  String title,
  String emoji,
  int minutes,
  int score,
  int hoursAgo,
) {
  final at = DateTime.now().subtract(Duration(hours: hoursAgo));
  return ConversationSession(
    id: 'sess_$id',
    scenarioId: id,
    scenarioTitle: title,
    emoji: emoji,
    startedAt: at,
    durationSeconds: minutes * 60,
    xpEarned: 60,
    messages: const [],
    summary: ConversationSummary(
      corrections: const [
        Correction(
          original: 'He go to school everyday.',
          corrected: 'He goes to school every day.',
          explanation:
              'With he / she / it in the simple present, the verb takes -s.',
        ),
      ],
      vocabulary: const [
        VocabUpgrade(simple: 'Good', better: 'Excellent'),
        VocabUpgrade(simple: 'Big', better: 'Huge'),
      ],
      phrases: const ['Could you repeat that, please?', 'What do you mean?'],
      slang: const [],
      fluencyScore: score,
      pronunciationScore: score - 4,
      confidenceScore: score + 2,
      encouragement: 'Really strong work — just a couple of small fixes.',
    ),
  ).toJson();
}
