import 'package:flutter/foundation.dart';

/// One day's practice record, backing the weekly activity chart and the
/// streak calculation.
@immutable
class DailyActivity {
  const DailyActivity({
    required this.date,
    this.minutes = 0,
    this.xp = 0,
    this.conversations = 0,
    this.lessons = 0,
  });

  /// Always midnight-normalised — see [dayKey].
  final DateTime date;
  final int minutes;
  final int xp;
  final int conversations;
  final int lessons;

  /// Stable `yyyy-MM-dd` key used as the map index in storage.
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime normalise(DateTime d) => DateTime(d.year, d.month, d.day);

  String get key => dayKey(date);

  DailyActivity copyWith({
    int? minutes,
    int? xp,
    int? conversations,
    int? lessons,
  }) =>
      DailyActivity(
        date: date,
        minutes: minutes ?? this.minutes,
        xp: xp ?? this.xp,
        conversations: conversations ?? this.conversations,
        lessons: lessons ?? this.lessons,
      );

  DailyActivity merge({
    int addMinutes = 0,
    int addXp = 0,
    int addConversations = 0,
    int addLessons = 0,
  }) =>
      DailyActivity(
        date: date,
        minutes: minutes + addMinutes,
        xp: xp + addXp,
        conversations: conversations + addConversations,
        lessons: lessons + addLessons,
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minutes': minutes,
        'xp': xp,
        'conversations': conversations,
        'lessons': lessons,
      };

  factory DailyActivity.fromJson(Map<String, dynamic> j) => DailyActivity(
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        conversations: (j['conversations'] as num?)?.toInt() ?? 0,
        lessons: (j['lessons'] as num?)?.toInt() ?? 0,
      );
}
