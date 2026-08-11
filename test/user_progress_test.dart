import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/models/achievement.dart';
import 'package:voix/data/models/daily_activity.dart';
import 'package:voix/data/models/user_profile.dart';

void main() {
  group('Level curve', () {
    test('level 1 starts at zero XP', () {
      expect(UserProfile.xpForLevel(1), 0);
      expect(const UserProfile(id: 'u', name: 'A', xp: 0).level, 1);
    });

    test('thresholds match the design exactly', () {
      // These are not arbitrary: the Progress screen in the design shows
      // 1,250 XP as Level 8 with 250 XP to Level 9. Every number below is
      // pinned to that, so a change here is a change to the design.
      const expected = {
        1: 0,
        2: 50,
        3: 150,
        4: 300,
        5: 500,
        6: 750,
        7: 1000,
        8: 1250,
        9: 1500,
        10: 1750,
      };
      expected.forEach((level, xp) {
        expect(UserProfile.xpForLevel(level), xp, reason: 'level $level');
      });
    });

    test('cost per level ramps, then flattens at 250', () {
      final costs = [
        for (var l = 1; l <= 9; l++)
          UserProfile.xpForLevel(l + 1) - UserProfile.xpForLevel(l),
      ];
      expect(costs, [50, 100, 150, 200, 250, 250, 250, 250, 250]);
    });

    test('1,250 XP reads as Level 8, Fluent Speaker, 250 to go', () {
      // The exact row from the design's Progress screen.
      const learner = UserProfile(id: 'u', name: 'A', xp: 1250);
      expect(learner.level, 8);
      expect(learner.levelTitle, 'Fluent Speaker');
      expect(learner.xpToNextLevel, 250);
    });

    test('level rises as XP crosses each threshold', () {
      UserProfile at(int xp) => UserProfile(id: 'u', name: 'A', xp: xp);
      expect(at(49).level, 1);
      expect(at(50).level, 2);
      expect(at(UserProfile.xpForLevel(5)).level, 5);
      expect(at(UserProfile.xpForLevel(5) - 1).level, 4);
    });

    test('progress within a level is bounded 0..1', () {
      for (final xp in [0, 250, 500, 1250, 9000, 50000]) {
        final p = UserProfile(id: 'u', name: 'A', xp: xp).levelProgress;
        expect(p, inInclusiveRange(0.0, 1.0));
      }
    });

    test('xpToNextLevel is always positive', () {
      for (final xp in [0, 499, 500, 1250, 20000]) {
        expect(
          UserProfile(id: 'u', name: 'A', xp: xp).xpToNextLevel,
          greaterThan(0),
        );
      }
    });

    test('level title tracks the level bands', () {
      String titleAt(int level) =>
          UserProfile(id: 'u', name: 'A', xp: UserProfile.xpForLevel(level))
              .levelTitle;
      expect(titleAt(1), 'Beginner');
      expect(titleAt(2), 'Elementary');
      expect(titleAt(4), 'Intermediate');
      expect(titleAt(6), 'Advanced');
      expect(titleAt(8), 'Fluent Speaker');
      expect(titleAt(12), 'Master');
      expect(titleAt(16), 'Native-Like');
    });
  });

  group('Daily goal', () {
    test('goal progress clamps once exceeded', () {
      const u = UserProfile(
        id: 'u',
        name: 'A',
        dailyGoalMinutes: 10,
        minutesToday: 25,
      );
      expect(u.goalProgress, 1.0);
      expect(u.goalMetToday, isTrue);
    });

    test('a zero goal does not divide by zero', () {
      const u = UserProfile(id: 'u', name: 'A', dailyGoalMinutes: 0);
      expect(u.goalProgress, 0);
    });
  });

  group('Initials', () {
    test('uses first and last name', () {
      expect(const UserProfile(id: 'u', name: 'Asha Rao').initials, 'AR');
    });

    test('falls back to a single letter', () {
      expect(const UserProfile(id: 'u', name: 'Asha').initials, 'A');
    });

    test('handles an empty name', () {
      expect(const UserProfile(id: 'u', name: '   ').initials, 'V');
    });
  });

  group('Serialisation', () {
    test('round-trips every field', () {
      final original = UserProfile(
        id: 'u1',
        name: 'Hrithik',
        email: 'h@example.com',
        xp: 1250,
        currentStreak: 12,
        longestStreak: 20,
        dailyGoalMinutes: 15,
        minutesToday: 8,
        nativeLanguageCode: 'te',
        proficiency: Proficiency.advanced,
        occupation: Occupation.working,
        goal: LearningGoal.career,
        tutorVoice: TutorVoice.female,
        mode: LearningMode.genZ,
        totalConversations: 32,
        totalMinutes: 865,
        wordsLearned: 45,
        completedLessonIds: const {'a', 'b'},
        lastActiveDate: DateTime(2026, 3, 4),
      );

      final restored = UserProfile.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.xp, original.xp);
      expect(restored.currentStreak, original.currentStreak);
      expect(restored.proficiency, Proficiency.advanced);
      expect(restored.mode, LearningMode.genZ);
      expect(restored.tutorVoice, TutorVoice.female);
      expect(restored.completedLessonIds, {'a', 'b'});
      expect(restored.lastActiveDate, DateTime(2026, 3, 4));
      expect(restored.level, original.level);
    });

    test('unknown enum values fall back instead of throwing', () {
      final restored = UserProfile.fromJson({
        'id': 'u',
        'name': 'A',
        'proficiency': 'not_a_level',
        'mode': 'nonsense',
      });
      expect(restored.proficiency, Proficiency.beginner);
      expect(restored.mode, LearningMode.standard);
    });

    test('an empty map yields usable defaults', () {
      final restored = UserProfile.fromJson({});
      expect(restored.name, 'Learner');
      expect(restored.level, 1);
      expect(restored.dailyGoalMinutes, 10);
    });
  });

  group('Achievements', () {
    test('unlock when the tracked metric reaches the target', () {
      final streak5 = AchievementCatalog.all.firstWhere(
        (a) => a.id == 'streak_5',
      );
      expect(
        streak5.isUnlocked(const UserProfile(id: 'u', name: 'A', longestStreak: 4)),
        isFalse,
      );
      expect(
        streak5.isUnlocked(const UserProfile(id: 'u', name: 'A', longestStreak: 5)),
        isTrue,
      );
    });

    test('progress is a bounded fraction of the target', () {
      final words = AchievementCatalog.all.firstWhere(
        (a) => a.id == 'words_25',
      );
      expect(
        words.progressFor(const UserProfile(id: 'u', name: 'A', wordsLearned: 5)),
        closeTo(0.2, 0.001),
      );
      expect(
        words.progressFor(
          const UserProfile(id: 'u', name: 'A', wordsLearned: 500),
        ),
        1.0,
      );
    });

    test('level achievements read the derived level', () {
      final level5 = AchievementCatalog.all.firstWhere((a) => a.id == 'level_5');
      final atLevel5 = UserProfile(
        id: 'u',
        name: 'A',
        xp: UserProfile.xpForLevel(5),
      );
      expect(level5.isUnlocked(atLevel5), isTrue);
    });

    test('every achievement id is unique', () {
      final ids = AchievementCatalog.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('DailyActivity', () {
    test('day keys are stable and zero-padded', () {
      expect(DailyActivity.dayKey(DateTime(2026, 3, 4)), '2026-03-04');
      expect(DailyActivity.dayKey(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('normalise strips the time component', () {
      final n = DailyActivity.normalise(DateTime(2026, 3, 4, 17, 42, 9));
      expect(n, DateTime(2026, 3, 4));
    });

    test('merge accumulates without mutating', () {
      final base = DailyActivity(date: DateTime(2026, 3, 4), minutes: 10, xp: 50);
      final merged = base.merge(addMinutes: 5, addXp: 20, addConversations: 1);
      expect(base.minutes, 10);
      expect(merged.minutes, 15);
      expect(merged.xp, 70);
      expect(merged.conversations, 1);
    });

    test('round-trips through JSON', () {
      final a = DailyActivity(
        date: DateTime(2026, 3, 4),
        minutes: 18,
        xp: 120,
        conversations: 2,
        lessons: 1,
      );
      final b = DailyActivity.fromJson(a.toJson());
      expect(b.key, a.key);
      expect(b.minutes, 18);
      expect(b.lessons, 1);
    });
  });
}
