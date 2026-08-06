import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';
import 'user_profile.dart';

/// What quantity an achievement tracks. Keeping the metric explicit lets
/// [Achievement.progressFor] compute state from a [UserProfile] without each
/// achievement carrying its own closure.
enum AchievementMetric {
  streak,
  conversations,
  lessons,
  xp,
  words,
  minutes,
  level,
}

@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.icon,
    required this.gradient,
    this.emoji = '🏆',
  });

  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
  final IconData icon;
  final Gradient gradient;
  final String emoji;

  /// Current raw value of this achievement's metric for [u].
  int valueFor(UserProfile u) => switch (metric) {
        AchievementMetric.streak => u.longestStreak,
        AchievementMetric.conversations => u.totalConversations,
        AchievementMetric.lessons => u.completedLessonIds.length,
        AchievementMetric.xp => u.xp,
        AchievementMetric.words => u.wordsLearned,
        AchievementMetric.minutes => u.totalMinutes,
        AchievementMetric.level => u.level,
      };

  double progressFor(UserProfile u) =>
      target == 0 ? 0 : (valueFor(u) / target).clamp(0.0, 1.0);

  bool isUnlocked(UserProfile u) => valueFor(u) >= target;
}

/// The full achievement set. Ordered roughly by how soon a new learner will
/// reach each one, which is also the order they appear in the grid.
abstract final class AchievementCatalog {
  static const all = <Achievement>[
    Achievement(
      id: 'first_conversation',
      title: 'First Conversation',
      description: 'Complete your first conversation',
      metric: AchievementMetric.conversations,
      target: 1,
      icon: Icons.mic_rounded,
      gradient: VoixGradients.brand,
      emoji: '🎙️',
    ),
    Achievement(
      id: 'first_lesson',
      title: 'Getting Started',
      description: 'Finish your first lesson',
      metric: AchievementMetric.lessons,
      target: 1,
      icon: Icons.school_rounded,
      gradient: VoixGradients.brandSoft,
      emoji: '📖',
    ),
    Achievement(
      id: 'streak_5',
      title: '5-Day Streak',
      description: 'Practise 5 days in a row',
      metric: AchievementMetric.streak,
      target: 5,
      icon: Icons.local_fire_department_rounded,
      gradient: VoixGradients.flame,
      emoji: '🔥',
    ),
    Achievement(
      id: 'level_5',
      title: 'Level 5 Reached',
      description: 'Reach level 5 in your journey',
      metric: AchievementMetric.level,
      target: 5,
      icon: Icons.star_rounded,
      gradient: VoixGradients.brandSoft,
      emoji: '⭐',
    ),
    Achievement(
      id: 'words_25',
      title: 'Word Collector',
      description: 'Learn 25 new words',
      metric: AchievementMetric.words,
      target: 25,
      icon: Icons.menu_book_rounded,
      gradient: VoixGradients.violetMagenta,
      emoji: '📚',
    ),
    Achievement(
      id: 'conversations_10',
      title: 'Chatterbox',
      description: 'Complete 10 conversations',
      metric: AchievementMetric.conversations,
      target: 10,
      icon: Icons.forum_rounded,
      gradient: VoixGradients.brand,
      emoji: '💬',
    ),
    Achievement(
      id: 'streak_12',
      title: 'Fortnight Fire',
      description: 'Practise 12 days in a row',
      metric: AchievementMetric.streak,
      target: 12,
      icon: Icons.whatshot_rounded,
      gradient: VoixGradients.flame,
      emoji: '🔥',
    ),
    Achievement(
      id: 'minutes_300',
      title: 'Five Hours In',
      description: 'Practise for 300 minutes total',
      metric: AchievementMetric.minutes,
      target: 300,
      icon: Icons.timer_rounded,
      gradient: VoixGradients.mint,
      emoji: '⏱️',
    ),
    Achievement(
      id: 'lessons_20',
      title: 'Dedicated Learner',
      description: 'Complete 20 lessons',
      metric: AchievementMetric.lessons,
      target: 20,
      icon: Icons.workspace_premium_rounded,
      gradient: VoixGradients.gold,
      emoji: '🎓',
    ),
    Achievement(
      id: 'level_10',
      title: 'Double Digits',
      description: 'Reach level 10',
      metric: AchievementMetric.level,
      target: 10,
      icon: Icons.military_tech_rounded,
      gradient: VoixGradients.gold,
      emoji: '🏅',
    ),
    Achievement(
      id: 'streak_30',
      title: 'Unstoppable',
      description: 'Practise 30 days in a row',
      metric: AchievementMetric.streak,
      target: 30,
      icon: Icons.bolt_rounded,
      gradient: VoixGradients.flame,
      emoji: '⚡',
    ),
    Achievement(
      id: 'xp_5000',
      title: 'XP Master',
      description: 'Earn 5,000 XP',
      metric: AchievementMetric.xp,
      target: 5000,
      icon: Icons.auto_awesome_rounded,
      gradient: VoixGradients.violetMagenta,
      emoji: '✨',
    ),
  ];

  static Achievement byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}
