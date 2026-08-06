import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/staggered.dart';
import '../../providers/user_controller.dart';
import 'settings_screen.dart';
import 'widgets/settings_tile.dart';

/// Reminder and streak notification preferences.
///
/// Preferences persist immediately; actually scheduling the local
/// notifications requires a platform plugin (see `docs/BACKEND.md`) — the
/// toggles below are the source of truth that scheduling will read from.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final controller = ref.read(userControllerProvider.notifier);
    final time = TimeOfDay(
      hour: user.reminderHour,
      minute: user.reminderMinute,
    );

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
                subtitle: 'Remind me to practise daily',
                showChevron: false,
                trailing: Switch(
                  value: user.remindersEnabled,
                  onChanged: (v) {
                    Haptic.tap();
                    controller.update((u) => u.copyWith(remindersEnabled: v));
                  },
                ),
              ),
              SettingsTile(
                icon: Icons.track_changes_rounded,
                title: 'Daily Goal Updates',
                subtitle: 'Notify me about my daily goal',
                iconColor: VoixPalette.violet,
                showChevron: false,
                trailing: Switch(
                  value: user.remindersEnabled,
                  onChanged: (v) {
                    Haptic.tap();
                    controller.update((u) => u.copyWith(remindersEnabled: v));
                  },
                ),
              ),
              SettingsTile(
                icon: Icons.local_fire_department_rounded,
                title: 'Streak Alerts',
                subtitle: 'Remind me to keep my streak',
                iconColor: VoixPalette.streak,
                showChevron: false,
                trailing: Switch(
                  value: user.remindersEnabled,
                  onChanged: (v) {
                    Haptic.tap();
                    controller.update((u) => u.copyWith(remindersEnabled: v));
                  },
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
            'Reminders are stored on this device. Delivery requires the local '
            'notification plugin described in docs/BACKEND.md.',
            style: context.text.labelSmall?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }
}
