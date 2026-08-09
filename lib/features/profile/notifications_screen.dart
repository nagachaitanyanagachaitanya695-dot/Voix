import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/staggered.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/notification_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';
import 'settings_screen.dart';
import 'widgets/settings_tile.dart';

/// Reminder and streak notification preferences.
///
/// Each switch rewrites the real schedule through `NotificationService`, so
/// what is shown here is what Android will actually deliver.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final controller = ref.read(userControllerProvider.notifier);
    final notifications = ref.read(notificationServiceProvider);
    final time = TimeOfDay(
      hour: user.reminderHour,
      minute: user.reminderMinute,
    );

    // Switching a reminder *on* is the one moment where asking for the OS
    // notification permission is expected, so only that direction prompts.
    void toggle(bool value, UserProfile Function(UserProfile, bool) edit) {
      Haptic.tap();
      controller.setReminderPreference(
        (u) => edit(u, value),
        prompting: value,
      );
    }

    return SettingsBody(
      title: 'Notifications',
      children: [
        const FadeSlideIn(
          child: SettingsHero(
            icon: Icons.notifications_active_rounded,
            title: 'Stay Updated',
            caption: 'Manage how you receive notifications from Voix.',
            color: VoixPalette.blue,
          ),
        ),
        Gap.h24,
        FadeSlideIn(
          index: 1,
          child: SettingsGroup(
            title: 'Notification Settings',
            tiles: [
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Practice Reminders',
                subtitle: 'A nudge at your chosen time each day',
                showChevron: false,
                trailing: Switch(
                  value: user.remindersEnabled,
                  onChanged: (v) =>
                      toggle(v, (u, on) => u.copyWith(remindersEnabled: on)),
                ),
              ),
              SettingsTile(
                icon: Icons.track_changes_rounded,
                title: 'Daily Goal Updates',
                subtitle: 'An afternoon check-in on your minutes',
                iconColor: VoixPalette.violet,
                showChevron: false,
                trailing: Switch(
                  value: user.goalUpdatesEnabled,
                  onChanged: (v) =>
                      toggle(v, (u, on) => u.copyWith(goalUpdatesEnabled: on)),
                ),
              ),
              SettingsTile(
                icon: Icons.local_fire_department_rounded,
                title: 'Streak Alerts',
                subtitle: 'An evening warning before a streak lapses',
                iconColor: VoixPalette.streak,
                showChevron: false,
                trailing: Switch(
                  value: user.streakAlertsEnabled,
                  onChanged: (v) =>
                      toggle(v, (u, on) => u.copyWith(streakAlertsEnabled: on)),
                ),
              ),
            ],
          ),
        ),
        Gap.h20,
        FadeSlideIn(
          index: 2,
          child: SettingsGroup(
            title: 'Timing',
            tiles: [
              SettingsTile(
                icon: Icons.schedule_rounded,
                title: 'Reminder Time',
                subtitle: 'When we nudge you each day',
                value: time.format(context),
                iconColor: VoixPalette.success,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked == null) return;
                  await controller.update(
                    (u) => u.copyWith(
                      reminderHour: picked.hour,
                      reminderMinute: picked.minute,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Gap.h16,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: Text(
            switch (notifications.blocker) {
              ReminderBlocker.permissionDenied =>
                'Notifications are switched off for Voix in your Android '
                    'settings, so these reminders cannot be delivered. Turn '
                    'them on under Settings › Apps › Voix › Notifications.',
              ReminderBlocker.unavailable =>
                'Reminders could not be scheduled on this device.',
              ReminderBlocker.none =>
                'Reminders are scheduled on this device — no account or '
                    'internet connection needed. Android may deliver them a '
                    'few minutes either side of the time shown so it can '
                    'batch them and save battery.',
            },
            style: context.text.labelSmall?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}
