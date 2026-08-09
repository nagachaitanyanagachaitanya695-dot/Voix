import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:voix/data/services/notification_service.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    // A zone with a half-hour offset and no daylight saving — the app's primary
    // audience, and the case a UTC-only implementation gets wrong.
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  });

  tz.TZDateTime at(int y, int m, int d, int h, int min) =>
      tz.TZDateTime(tz.local, y, m, d, h, min);

  group('NotificationService.nextOccurrence', () {
    test('schedules later today when the time has not passed', () {
      final next = NotificationService.nextOccurrence(
        19,
        0,
        now: at(2026, 3, 10, 9, 15),
      );
      expect(next, at(2026, 3, 10, 19, 0));
    });

    test('rolls to tomorrow when the time has already passed', () {
      final next = NotificationService.nextOccurrence(
        7,
        30,
        now: at(2026, 3, 10, 9, 15),
      );
      expect(next, at(2026, 3, 11, 7, 30));
    });

    test('rolls forward when the time is exactly now', () {
      // Scheduling for the current instant makes the plugin fire immediately,
      // which would ambush someone who just picked their reminder time.
      final next = NotificationService.nextOccurrence(
        9,
        15,
        now: at(2026, 3, 10, 9, 15),
      );
      expect(next, at(2026, 3, 11, 9, 15));
    });

    test('crosses a month boundary correctly', () {
      final next = NotificationService.nextOccurrence(
        6,
        0,
        now: at(2026, 1, 31, 23, 45),
      );
      expect(next, at(2026, 2, 1, 6, 0));
    });

    test('crosses a year boundary correctly', () {
      final next = NotificationService.nextOccurrence(
        8,
        0,
        now: at(2026, 12, 31, 22, 0),
      );
      expect(next, at(2027, 1, 1, 8, 0));
    });

    test('resolves in the local zone, not UTC', () {
      final next = NotificationService.nextOccurrence(
        19,
        0,
        now: at(2026, 3, 10, 9, 15),
      );
      expect(next.location.name, 'Asia/Kolkata');
      // 19:00 IST is 13:30 UTC — proof the wall-clock time is being preserved
      // rather than the instant.
      expect(next.toUtc().hour, 13);
      expect(next.toUtc().minute, 30);
    });

    test('handles a leap day', () {
      final next = NotificationService.nextOccurrence(
        6,
        0,
        now: at(2028, 2, 28, 23, 0),
      );
      expect(next, at(2028, 2, 29, 6, 0));
    });
  });

  group('NotificationService in a bare test environment', () {
    test('init records unavailability instead of throwing', () async {
      // There is no plugin host in a unit test, so every platform call fails.
      // The service must absorb that: a reminder that cannot be scheduled is
      // never a reason to take the app down.
      final service = NotificationService();
      await expectLater(service.init(), completes);
      expect(service.blocker, ReminderBlocker.unavailable);
    });

    test('sync is a no-op when the plugin never initialised', () async {
      final service = NotificationService();
      await service.init();
      await expectLater(service.cancelAll(), completes);
    });
  });
}
