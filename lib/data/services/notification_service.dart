import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/user_profile.dart';

/// Why a reminder could not be scheduled, so the UI can say something true
/// rather than showing a switch that silently does nothing.
enum ReminderBlocker {
  /// Everything is fine.
  none,

  /// The learner declined the Android 13+ notification prompt.
  permissionDenied,

  /// The plugin failed to initialise — no notifications are possible.
  unavailable,
}

/// Schedules the daily practice reminders.
///
/// Three independent notifications, each of which the learner can turn off on
/// its own:
///
///   * **Practice reminder** — at the time they picked.
///   * **Daily goal check-in** — mid-afternoon, framed around the goal.
///   * **Streak alert** — late evening, and only while a streak is running.
///
/// All three are scheduled *inexactly*. Play restricts the exact-alarm
/// permissions to alarm and calendar apps, and a nudge to practise does not
/// need to land on a particular second — the OS is free to batch it with other
/// wakeups, which is also much kinder to the battery.
///
/// Nothing here can run code in the background: Android delivers a
/// pre-composed notification while the app is dead. So the text is baked in at
/// scheduling time, and [sync] is called again on every profile change to keep
/// it current.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool _initFailed = false;
  ReminderBlocker _blocker = ReminderBlocker.none;

  /// Ceiling on any single platform call that is not waiting for the learner.
  ///
  /// Setting up notifications happens on the path of a settings toggle and of
  /// app startup. A plugin that never answers — a broken vendor ROM, a channel
  /// with no handler — would otherwise hang both forever. Reminders are worth
  /// waiting a few seconds for; they are not worth a frozen switch.
  static const _callLimit = Duration(seconds: 5);

  /// The most recent reason scheduling was refused. Surfaced in Settings.
  ReminderBlocker get blocker => _blocker;

  // Stable ids, so rescheduling replaces rather than duplicates.
  static const _idPractice = 1001;
  static const _idGoal = 1002;
  static const _idStreak = 1003;

  static const _channel = AndroidNotificationChannel(
    'voix_reminders',
    'Practice reminders',
    description: 'Daily nudges to practise, goal check-ins and streak alerts.',
    importance: Importance.defaultImportance,
  );

  /// Prepares the plugin and the timezone database.
  ///
  /// Safe to call more than once, and safe to call on a platform where none of
  /// this exists — every failure is swallowed into [blocker] rather than
  /// thrown, because a reminder failing to schedule must never stop the app
  /// from starting.
  Future<void> init() async {
    if (_ready || _initFailed) return;
    try {
      tzdata.initializeTimeZones();
      // The device's own zone, so 7pm means 7pm where the learner is — and
      // keeps meaning that after they fly somewhere else.
      final info = await FlutterTimezone.getLocalTimezone().timeout(_callLimit);
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // tz.local defaults to UTC, which is wrong but survivable — better than
      // no reminders at all.
      debugPrint('NotificationService: timezone lookup failed ($e), using UTC');
    }

    try {
      await _plugin
          .initialize(
            settings: const InitializationSettings(
              // Uses the launcher icon; Android tints it to a white silhouette.
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            ),
          )
          .timeout(_callLimit);
      await _android?.createNotificationChannel(_channel).timeout(_callLimit);
      _ready = true;
      _blocker = ReminderBlocker.none;
    } catch (e) {
      debugPrint('NotificationService: initialize failed ($e)');
      _blocker = ReminderBlocker.unavailable;
      // Remembered for the rest of the process. A plugin that cannot be
      // initialised will not start working later in the same run, and retrying
      // would put the timeout above in front of every settings tap. A relaunch
      // gets a clean attempt.
      _initFailed = true;
    }
  }

  /// Asks for the Android 13+ notification permission.
  ///
  /// Returns whether notifications may now be posted. On Android 12 and below
  /// the permission is granted at install time and this resolves true without
  /// showing anything.
  Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      // No limit here: this one legitimately blocks on the learner tapping
      // "Allow", and cutting that off after a few seconds would report a
      // denial they never made.
      final granted = await _android?.requestNotificationsPermission() ?? true;
      _blocker = granted ? ReminderBlocker.none : ReminderBlocker.permissionDenied;
      return granted;
    } catch (e) {
      debugPrint('NotificationService: permission request failed ($e)');
      _blocker = ReminderBlocker.unavailable;
      return false;
    }
  }

  /// Rewrites the whole schedule to match [user].
  ///
  /// Called after sign-in and after any change to the reminder settings, the
  /// daily goal, or the streak — the notification text quotes all three, and a
  /// stale "keep your 3-day streak" when they are on 11 reads as a bug.
  ///
  /// Set [prompt] only when the learner just asked for reminders. The system
  /// permission dialog is jarring if it appears while they are finishing a
  /// lesson, so background resyncs schedule quietly and let Android drop the
  /// notifications if permission was never granted.
  Future<void> sync(UserProfile user, {bool prompt = false}) async {
    await init();
    if (!_ready) return;

    await cancelAll();

    final wantsAny = user.remindersEnabled ||
        user.goalUpdatesEnabled ||
        user.streakAlertsEnabled;
    if (!wantsAny) return;

    if (prompt && !await requestPermission()) return;

    if (user.remindersEnabled) {
      await _scheduleDaily(
        id: _idPractice,
        hour: user.reminderHour,
        minute: user.reminderMinute,
        title: 'Time to practise, ${user.name.split(' ').first} 👋',
        body: user.dailyGoalMinutes > 0
            ? '${user.dailyGoalMinutes} minutes of conversation is all it takes.'
            : 'A few minutes of conversation is all it takes.',
      );
    }

    if (user.goalUpdatesEnabled) {
      await _scheduleDaily(
        id: _idGoal,
        hour: 15,
        minute: 30,
        title: 'Daily goal check-in',
        body: 'Have you hit your ${user.dailyGoalMinutes}-minute goal today? '
            'There is still plenty of day left.',
      );
    }

    // A streak alert only makes sense once there is a streak to lose.
    if (user.streakAlertsEnabled && user.currentStreak > 0) {
      await _scheduleDaily(
        id: _idStreak,
        hour: 21,
        minute: 0,
        title: 'Don\'t break your ${user.currentStreak}-day streak 🔥',
        body: 'One short conversation keeps it alive.',
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      for (final id in [_idPractice, _idGoal, _idStreak]) {
        await _plugin.cancel(id: id).timeout(_callLimit);
      }
    } catch (e) {
      debugPrint('NotificationService: cancel failed ($e)');
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: _nextOccurrence(hour, minute),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            // The brand cyan, used for the small-icon tint in the shade.
            color: const Color(0xFF22D8F0),
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        // See the class comment: exact alarms are a Play policy risk and are
        // not needed for a study reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeats every day at this wall-clock time.
        matchDateTimeComponents: DateTimeComponents.time,
      ).timeout(_callLimit);
    } catch (e) {
      debugPrint('NotificationService: schedule $id failed ($e)');
    }
  }

  /// The next [hour]:[minute] in the device's timezone — today if it is still
  /// ahead of us, otherwise tomorrow. Scheduling a time in the past makes the
  /// plugin fire immediately, which is a jarring way to meet a new setting.
  @visibleForTesting
  static tz.TZDateTime nextOccurrence(int hour, int minute, {DateTime? now}) {
    final base = now == null
        ? tz.TZDateTime.now(tz.local)
        : tz.TZDateTime.from(now, tz.local);
    var next = tz.TZDateTime(tz.local, base.year, base.month, base.day, hour, minute);
    if (!next.isAfter(base)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  tz.TZDateTime _nextOccurrence(int hour, int minute) =>
      nextOccurrence(hour, minute);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
}
