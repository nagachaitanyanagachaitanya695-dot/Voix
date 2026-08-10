import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/staggered.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/app_providers.dart';
import '../../providers/session_controller.dart';
import '../../providers/user_controller.dart';
import '../onboarding/onboarding_flow.dart';
import 'settings_screen.dart';
import 'widgets/settings_tile.dart';

/// Data and privacy controls.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsBody(
      title: 'Privacy',
      children: [
        const FadeSlideIn(
          child: SettingsHero(
            icon: Icons.shield_rounded,
            title: 'Your Privacy Matters',
            caption: "We're committed to protecting your data and privacy.",
            color: VoixPalette.violet,
          ),
        ),
        Gap.h24,
        FadeSlideIn(
          index: 1,
          child: SettingsGroup(
            title: 'Privacy Settings',
            tiles: [
              SettingsTile(
                icon: Icons.visibility_off_rounded,
                title: 'Profile Visibility',
                subtitle: 'Control who can see your profile',
                value: 'Private',
                iconColor: VoixPalette.violet,
                onTap: () => showNotWiredUp(context, 'Profile visibility'),
              ),
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Data Usage',
                subtitle: 'Manage how we use your data',
                onTap: () => _showDataSheet(context, ref),
              ),
              SettingsTile(
                icon: Icons.history_rounded,
                title: 'Clear Conversation History',
                subtitle: 'Delete saved transcripts and reports',
                iconColor: VoixPalette.warning,
                onTap: () => _confirmClearHistory(context, ref),
              ),
              SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                destructive: true,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
        Gap.h16,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
          child: Text(
            'Your conversations, progress and preferences are stored on this '
            'device. Nothing is uploaded unless you connect an account.',
            style: context.text.labelSmall?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }

  void _showDataSheet(BuildContext context, WidgetRef ref) {
    // What is true here depends on whether the build has a backend: with
    // Firebase off, progress genuinely never leaves the phone. Saying so
    // unconditionally would become a false privacy claim the moment an account
    // is configured, which is the one kind of copy that must never go stale.
    final syncing = ref.read(firebaseReadyProvider);

    showModalBottomSheet<void>(
      context: context,
      // A modal sheet is capped at a fraction of the screen height, and this
      // one is dense text that grows further at large accessibility text
      // scales. Scrollable so it can never clip a privacy disclosure.
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data Usage', style: context.text.headlineSmall),
              Gap.h16,
              for (final item in [
                (
                  Icons.mic_rounded,
                  'Voice',
                  'Voix never records or stores audio. Your speech is passed '
                      'to your phone\'s own recogniser to be turned into text '
                      '— on most Android phones that is Google\'s, which may '
                      'send the audio to Google to transcribe. You can type '
                      'to the tutor instead.',
                ),
                (
                  Icons.forum_rounded,
                  'Conversations',
                  syncing
                      ? 'Transcripts and feedback reports are saved on this '
                          'device and backed up to your account.'
                      : 'Transcripts and feedback reports are saved on this '
                          'device only.',
                ),
                (
                  Icons.insights_rounded,
                  'Progress',
                  syncing
                      ? 'XP, streaks and activity history are backed up to '
                          'your account so a new phone restores them.'
                      : 'XP, streaks and activity history stay on this device. '
                          'Uninstalling the app erases them.',
                ),
                (
                  Icons.block_rounded,
                  'No tracking',
                  'No advertising, no analytics, and nothing sold or shared '
                      'with anyone.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.$1,
                        size: 19,
                        color: context.colors.primary,
                      ),
                      Gap.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2, style: context.text.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              item.$3,
                              style: context.text.bodySmall
                                  ?.copyWith(height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear conversation history?'),
        content: const Text(
          'Your saved transcripts and feedback reports will be deleted. '
          'Your XP, streak and level are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(sessionHistoryProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Conversation history cleared.')),
      );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your profile, progress, streak and every '
          'saved conversation — from this device and from your Voix account. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete everything',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(userControllerProvider.notifier).deleteAccount();
    } on AuthException catch (e) {
      // Firebase refuses to delete an account whose sign-in is more than a few
      // minutes old, so this is a routine outcome rather than a rare failure.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (_) => false,
    );
  }
}
