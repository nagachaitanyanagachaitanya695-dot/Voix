import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/xp_bar.dart';
import '../../data/models/language.dart';
import '../../data/models/user_profile.dart';
import '../../providers/user_controller.dart';
import '../auth/auth_screen.dart';
import 'help_screen.dart';
import 'notifications_screen.dart';
import 'premium_screen.dart';
import 'privacy_screen.dart';
import 'settings_screen.dart';
import 'widgets/settings_tile.dart';

/// Account home: identity, level, preferences, and the settings entry points.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final native = LanguageCatalog.byCode(user.nativeLanguageCode);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 110),
        children: [
          // ── Header ────────────────────────────────────────────────
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.only(top: Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Profile', style: context.text.displaySmall),
                  ),
                  StreakPill(days: user.currentStreak),
                ],
              ),
            ),
          ),

          Gap.h20,

          // ── Identity card ─────────────────────────────────────────
          FadeSlideIn(
            index: 1,
            child: GlassCard(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Avatar(user: user),
                      Gap.w16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Hi, ${user.name.split(' ').first}',
                                    style: context.text.headlineSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Gap.w4,
                                const Text('👋',
                                    style: TextStyle(fontSize: 17)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.isGuest
                                  ? 'Guest account'
                                  : (user.email ?? 'Signed in'),
                              style: context.text.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Gap.h16,
                  Container(
                    padding: const EdgeInsets.all(Gap.sm + 2),
                    decoration: BoxDecoration(
                      color: c.isDark ? c.surfaceHigh : c.bgAlt,
                      borderRadius: Radii.rMd,
                    ),
                    child: Row(
                      children: [
                        LevelBadge(level: user.level, size: 40),
                        Gap.w12,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Level ${user.level}',
                              style: context.text.titleSmall?.copyWith(
                                color: VoixPalette.blue,
                              ),
                            ),
                            Text(
                              user.levelTitle,
                              style: context.text.labelSmall?.copyWith(
                                color: VoixPalette.violet,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          margin: const EdgeInsets.symmetric(
                            horizontal: Gap.sm,
                          ),
                          color: c.border,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${CountUp.format(user.xp)} XP',
                                style: VoixType.stat(
                                  17,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${CountUp.format(user.xpToNextLevel)} to next level',
                                style: context.text.labelSmall
                                    ?.copyWith(fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              XpBar(progress: user.levelProgress, height: 5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.h16,
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                          emoji: '🔥',
                          value: '${user.currentStreak} '
                              '${user.currentStreak == 1 ? "Day" : "Days"}',
                          label: 'Current Streak',
                        ),
                      ),
                      Container(width: 1, height: 38, color: c.border),
                      Expanded(
                        child: _MiniStat(
                          icon: Icons.track_changes_rounded,
                          iconColor: VoixPalette.indigo,
                          value: '${user.minutesToday} / '
                              '${user.dailyGoalMinutes} mins',
                          label: "Today's Goal",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Gap.h24,

          // ── Preferences ───────────────────────────────────────────
          FadeSlideIn(
            index: 2,
            child: SettingsGroup(
              title: 'Preferences',
              tiles: [
                SettingsTile(
                  icon: Icons.mic_none_rounded,
                  title: 'AI Tutor Voice',
                  subtitle: 'Choose your preferred voice',
                  value: user.tutorVoice.label,
                  onTap: () => _pickVoice(context, ref, user),
                ),
                SettingsTile(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: 'Your native language',
                  value: native.nativeName,
                  valueColor: VoixPalette.violet,
                  iconColor: VoixPalette.violet,
                  onTap: () => _pickLanguage(context, ref, user),
                ),
                SettingsTile(
                  icon: Icons.track_changes_rounded,
                  title: 'Daily Goal',
                  subtitle: 'Set your daily practice time',
                  value: '${user.dailyGoalMinutes} minutes',
                  valueColor: VoixPalette.success,
                  iconColor: VoixPalette.success,
                  onTap: () => _pickGoal(context, ref, user),
                ),
              ],
            ),
          ),

          Gap.h24,

          // ── Account ───────────────────────────────────────────────
          FadeSlideIn(
            index: 3,
            child: SettingsGroup(
              title: 'Account',
              tiles: [
                SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Manage your notification settings',
                  onTap: () => _push(context, const NotificationsScreen()),
                ),
                SettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy',
                  subtitle: 'Manage your data & privacy',
                  iconColor: VoixPalette.violet,
                  onTap: () => _push(context, const PrivacyScreen()),
                ),
                SettingsTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'App, voice, and general settings',
                  onTap: () => _push(context, const SettingsScreen()),
                ),
                SettingsTile(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Go Pro',
                  subtitle: 'Unlock unlimited practice & more',
                  iconColor: VoixPalette.gold,
                  showChevron: false,
                  trailing: _UpgradeButton(
                    isPro: user.isPro,
                    onTap: () => _showPro(context, ref, user),
                  ),
                  onTap: () => _showPro(context, ref, user),
                ),
                SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get help and contact support',
                  onTap: () => _push(context, const HelpScreen()),
                ),
              ],
            ),
          ),

          Gap.h16,

          // ── Sign out ──────────────────────────────────────────────
          FadeSlideIn(
            index: 4,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.sm + 2,
                vertical: Gap.xxs,
              ),
              child: SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out from your account',
                destructive: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
            ),
          ),

          Gap.h20,
          Center(
            child: Text(
              'Voix 1.0.0',
              style: context.text.labelSmall?.copyWith(color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // ── Preference pickers ─────────────────────────────────────────────────
  Future<void> _pickVoice(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    final choice = await _showPicker<TutorVoice>(
      context,
      title: 'AI Tutor Voice',
      options: TutorVoice.values,
      selected: user.tutorVoice,
      labelOf: (v) => v.label,
      iconOf: (v) =>
          v == TutorVoice.male ? Icons.mic_rounded : Icons.mic_none_rounded,
    );
    if (choice == null) return;
    await ref
        .read(userControllerProvider.notifier)
        .update((u) => u.copyWith(tutorVoice: choice));
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    final options = LanguageCatalog.nativeOptions;
    final choice = await _showPicker<Language>(
      context,
      title: 'Native Language',
      options: options,
      selected: LanguageCatalog.byCode(user.nativeLanguageCode),
      labelOf: (l) => l.displayName,
      emojiOf: (l) => l.flag,
    );
    if (choice == null) return;
    await ref
        .read(userControllerProvider.notifier)
        .update((u) => u.copyWith(nativeLanguageCode: choice.code));
  }

  Future<void> _pickGoal(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    const options = [5, 10, 15, 20, 30];
    final choice = await _showPicker<int>(
      context,
      title: 'Daily Goal',
      options: options,
      selected: options.contains(user.dailyGoalMinutes)
          ? user.dailyGoalMinutes
          : 10,
      labelOf: (m) => '$m minutes a day',
      iconOf: (_) => Icons.track_changes_rounded,
    );
    if (choice == null) return;
    await ref
        .read(userControllerProvider.notifier)
        .update((u) => u.copyWith(dailyGoalMinutes: choice));
  }

  Future<void> _showPro(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
    if (user.isPro) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('You already have Voix Pro. Thank you!')),
        );
      return;
    }
    // A full screen rather than the old marketing sheet: this one takes money,
    // and a payment flow needs room for the price, the restore option and the
    // Play billing terms.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(
          ref.read(userControllerProvider)?.isGuest == true
              ? 'You are signed in as a guest. Logging out will keep your '
                  'progress on this device, but you will need to set up again.'
              : 'Your progress is saved. You can log back in any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(userControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }
}

/// Generic single-select bottom sheet used by all preference rows.
Future<T?> _showPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T selected,
  required String Function(T) labelOf,
  IconData Function(T)? iconOf,
  String Function(T)? emojiOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: context.text.headlineSmall),
            ),
          ),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: 2,
              ),
              child: _PickerRow(
                label: labelOf(option),
                emoji: emojiOf?.call(option),
                icon: iconOf?.call(option),
                selected: option == selected,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            ),
          Gap.h24,
        ],
      ),
    ),
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () {
        Haptic.tap();
        onTap();
      },
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  c.primary.withValues(alpha: c.isDark ? 0.14 : 0.08),
                  c.surface,
                )
              : Colors.transparent,
          borderRadius: Radii.rMd,
          border: Border.all(
            color: selected ? c.primary : c.border,
          ),
        ),
        child: Row(
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 18))
            else if (icon != null)
              Icon(
                icon,
                size: 19,
                color: selected ? c.primary : c.textSecondary,
              ),
            Gap.w12,
            Expanded(
              child: Text(
                label,
                style: context.text.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 20, color: c.primary),
          ],
        ),
      ),
    );
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              gradient: VoixGradients.brand,
              shape: BoxShape.circle,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                user.initials,
                style: VoixType.stat(24, color: c.textPrimary),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                gradient: VoixGradients.brandSoft,
                shape: BoxShape.circle,
                border: Border.all(color: c.bg, width: 2),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    this.emoji,
    this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final String? emoji;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (emoji != null)
          Text(emoji!, style: const TextStyle(fontSize: 20))
        else if (icon != null)
          Icon(icon, size: 20, color: iconColor ?? context.colors.primary),
        Gap.w8,
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.isPro, required this.onTap});
  final bool isPro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isPro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.gold.withValues(alpha: 0.16),
          borderRadius: Radii.rPill,
        ),
        child: Text(
          'Active',
          style: context.text.labelSmall?.copyWith(
            color: context.colors.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2, vertical: 7),
        decoration: BoxDecoration(
          gradient: VoixGradients.brandSoft,
          borderRadius: Radii.rPill,
          boxShadow: [
            BoxShadow(
              color: VoixPalette.indigo.withValues(alpha: 0.4),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Text(
          'Upgrade',
          style: context.text.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

