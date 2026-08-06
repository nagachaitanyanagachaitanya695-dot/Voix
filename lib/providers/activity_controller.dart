import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/daily_activity.dart';
import '../data/repositories/local_store.dart';
import 'app_providers.dart';

/// Per-day practice history, keyed by `yyyy-MM-dd`.
///
/// Backs the weekly chart on Home and Progress. Kept separate from the user
/// profile because it grows unbounded and is only needed by the charts.
class ActivityController extends Notifier<Map<String, DailyActivity>> {
  @override
  Map<String, DailyActivity> build() {
    final raw = ref.read(localStoreProvider).getJsonList(LocalStore.kActivity);
    final map = <String, DailyActivity>{};
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        final a = DailyActivity.fromJson(entry);
        map[a.key] = a;
      }
    }
    return map;
  }

  Future<void> record({
    int minutes = 0,
    int xp = 0,
    int conversations = 0,
    int lessons = 0,
    DateTime? when,
  }) async {
    final day = DailyActivity.normalise(when ?? DateTime.now());
    final key = DailyActivity.dayKey(day);
    final existing = state[key] ?? DailyActivity(date: day);

    final updated = {
      ...state,
      key: existing.merge(
        addMinutes: minutes,
        addXp: xp,
        addConversations: conversations,
        addLessons: lessons,
      ),
    };

    state = updated;
    await _persist(updated);
  }

  Future<void> _persist(Map<String, DailyActivity> map) async {
    // Only the last 120 days are kept — enough for every chart the app shows,
    // and it bounds what would otherwise grow forever in local storage.
    final cutoff = DateTime.now().subtract(const Duration(days: 120));
    final trimmed = map.values.where((a) => a.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    await ref
        .read(localStoreProvider)
        .setJsonList(LocalStore.kActivity, trimmed.map((a) => a.toJson()).toList());
  }

  DailyActivity forDay(DateTime day) {
    final n = DailyActivity.normalise(day);
    return state[DailyActivity.dayKey(n)] ?? DailyActivity(date: n);
  }
}

final activityControllerProvider =
    NotifierProvider<ActivityController, Map<String, DailyActivity>>(
  ActivityController.new,
);

/// The current week (Monday → Sunday) as an ordered list, gap-filled with
/// zero-value days so the chart always shows seven columns.
final currentWeekActivityProvider = Provider<List<DailyActivity>>((ref) {
  final map = ref.watch(activityControllerProvider);
  final today = DailyActivity.normalise(DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));

  return List.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    return map[DailyActivity.dayKey(day)] ?? DailyActivity(date: day);
  });
});

/// The trailing 7 days ending today — used where "this week" should mean
/// "the last seven days" rather than the calendar week.
final lastSevenDaysProvider = Provider<List<DailyActivity>>((ref) {
  final map = ref.watch(activityControllerProvider);
  final today = DailyActivity.normalise(DateTime.now());
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    return map[DailyActivity.dayKey(day)] ?? DailyActivity(date: day);
  });
});
