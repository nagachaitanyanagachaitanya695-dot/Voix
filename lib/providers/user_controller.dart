import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/achievement.dart';
import '../data/models/daily_activity.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/local_store.dart';
import 'app_providers.dart';

/// Everything a completed practice contributes, so streak, XP, activity
/// history and achievements all advance from one call.
class PracticeOutcome {
  const PracticeOutcome({
    required this.xpEarned,
    required this.minutes,
    this.conversations = 0,
    this.lessons = 0,
    this.wordsLearned = 0,
    this.lessonId,
  });

  final int xpEarned;
  final int minutes;
  final int conversations;
  final int lessons;
  final int wordsLearned;
  final String? lessonId;
}

/// What changed as a result of [UserController.registerPractice] — the UI uses
/// this to decide whether to show a level-up or achievement celebration.
class PracticeReward {
  const PracticeReward({
    required this.xpEarned,
    required this.leveledUp,
    required this.newLevel,
    required this.streakIncreased,
    required this.streak,
    required this.unlocked,
  });

  final int xpEarned;
  final bool leveledUp;
  final int newLevel;
  final bool streakIncreased;
  final int streak;
  final List<Achievement> unlocked;

  bool get hasCelebration =>
      leveledUp || unlocked.isNotEmpty || streakIncreased;
}

/// Owns the learner record: persistence, streak rules, XP, and achievements.
class UserController extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final store = ref.read(localStoreProvider);
    if (!store.getBool(LocalStore.kSignedIn)) return null;
    final json = store.getJson(LocalStore.kProfile);
    if (json == null) return null;
    return _rolloverDay(UserProfile.fromJson(json));
  }

  LocalStore get _store => ref.read(localStoreProvider);

  /// Zeroes today's minutes when the stored profile is from a previous day,
  /// and drops a streak that has already been broken. Runs on every load so
  /// the home screen is correct even if the app was killed overnight.
  UserProfile _rolloverDay(UserProfile p) {
    final last = p.lastActiveDate;
    if (last == null) return p;

    final today = DailyActivity.normalise(DateTime.now());
    final lastDay = DailyActivity.normalise(last);
    if (lastDay == today) return p;

    final missedDays = today.difference(lastDay).inDays;
    return p.copyWith(
      minutesToday: 0,
      // One missed day still leaves the streak alive until that day ends;
      // two or more means it is gone.
      currentStreak: missedDays > 1 ? 0 : p.currentStreak,
    );
  }

  Future<void> _persist(UserProfile p) async {
    state = p;
    await _store.setJson(LocalStore.kProfile, p.toJson());
  }

  // ── Session lifecycle ──────────────────────────────────────────────────
  Future<void> setProfile(UserProfile profile) => _persist(profile);

  /// Applies an arbitrary edit and saves. All settings screens go through here.
  Future<void> update(UserProfile Function(UserProfile) edit) async {
    final current = state;
    if (current == null) return;
    await _persist(edit(current));
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }

  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    state = null;
    await ref.read(onboardingControllerProvider.notifier).reset();
  }

  // ── Progress ───────────────────────────────────────────────────────────
  /// Records a finished lesson or conversation and returns what it unlocked.
  Future<PracticeReward> registerPractice(PracticeOutcome outcome) async {
    final before = state;
    if (before == null) {
      return const PracticeReward(
        xpEarned: 0,
        leveledUp: false,
        newLevel: 1,
        streakIncreased: false,
        streak: 0,
        unlocked: [],
      );
    }

    final now = DateTime.now();
    final today = DailyActivity.normalise(now);
    final lastDay = before.lastActiveDate == null
        ? null
        : DailyActivity.normalise(before.lastActiveDate!);

    // ── Streak rules ────────────────────────────────────────────────────
    // Same day: unchanged. Yesterday: +1. Anything older (or first ever): 1.
    final int streak;
    final bool streakIncreased;
    if (lastDay == null) {
      streak = 1;
      streakIncreased = true;
    } else if (lastDay == today) {
      streak = max(before.currentStreak, 1);
      streakIncreased = false;
    } else if (today.difference(lastDay).inDays == 1) {
      streak = before.currentStreak + 1;
      streakIncreased = true;
    } else {
      streak = 1;
      streakIncreased = true;
    }

    final minutesToday =
        (lastDay == today ? before.minutesToday : 0) + outcome.minutes;

    final after = before.copyWith(
      xp: before.xp + outcome.xpEarned,
      currentStreak: streak,
      longestStreak: max(before.longestStreak, streak),
      minutesToday: minutesToday,
      totalMinutes: before.totalMinutes + outcome.minutes,
      totalConversations: before.totalConversations + outcome.conversations,
      wordsLearned: before.wordsLearned + outcome.wordsLearned,
      completedLessonIds: outcome.lessonId == null
          ? before.completedLessonIds
          : {...before.completedLessonIds, outcome.lessonId!},
      lastActiveDate: now,
    );

    // ── Achievements ────────────────────────────────────────────────────
    final newlyUnlocked = AchievementCatalog.all
        .where((a) => a.isUnlocked(after) && !a.isUnlocked(before))
        .toList();

    final withAchievements = after.copyWith(
      unlockedAchievementIds: {
        ...after.unlockedAchievementIds,
        ...newlyUnlocked.map((a) => a.id),
      },
    );

    await _persist(withAchievements);

    return PracticeReward(
      xpEarned: outcome.xpEarned,
      leveledUp: withAchievements.level > before.level,
      newLevel: withAchievements.level,
      streakIncreased: streakIncreased,
      streak: streak,
      unlocked: newlyUnlocked,
    );
  }
}

final userControllerProvider =
    NotifierProvider<UserController, UserProfile?>(UserController.new);

/// True when a learner is signed in.
final isSignedInProvider =
    Provider<bool>((ref) => ref.watch(userControllerProvider) != null);

/// Achievements split into unlocked / locked, ordered for the grid.
final achievementsProvider = Provider<List<Achievement>>((ref) {
  final user = ref.watch(userControllerProvider);
  if (user == null) return AchievementCatalog.all;
  final all = [...AchievementCatalog.all];
  all.sort((a, b) {
    final au = a.isUnlocked(user) ? 0 : 1;
    final bu = b.isUnlocked(user) ? 0 : 1;
    if (au != bu) return au - bu;
    return b.progressFor(user).compareTo(a.progressFor(user));
  });
  return all;
});
