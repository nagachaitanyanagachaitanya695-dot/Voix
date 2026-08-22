import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_config.dart';
import '../../core/config/build_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/voix_logo.dart';
import '../../data/models/language.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';
import 'testing_screen.dart';
import 'widgets/settings_tile.dart';

/// App-level settings: appearance, sound, and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final native = LanguageCatalog.byCode(user.nativeLanguageCode);

    return Scaffold(
      body: AuroraBackground(
        animate: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Gap.xxl),
            children: [
              const SettingsAppBar(title: 'Settings'),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Column(
                  children: [
                    const FadeSlideIn(
                      child: SettingsHero(
                        icon: Icons.settings_rounded,
                        title: 'App Settings',
                        caption: 'Customise your Voix experience.',
                        color: VoixPalette.violet,
                      ),
                    ),
                    Gap.h24,

                    // ── Appearance ────────────────────────────────
                    FadeSlideIn(
                      index: 1,
                      child: SettingsGroup(
                        title: 'Appearance',
                        tiles: [
                          SettingsTile(
                            icon: switch (themeMode) {
                              ThemeMode.dark => Icons.dark_mode_rounded,
                              ThemeMode.light => Icons.light_mode_rounded,
                              ThemeMode.system => Icons.brightness_auto_rounded,
                            },
                            title: 'Theme',
                            subtitle: 'Dark, light, or follow your device',
                            value: switch (themeMode) {
                              ThemeMode.dark => 'Dark',
                              ThemeMode.light => 'Light',
                              ThemeMode.system => 'System',
                            },
                            iconColor: VoixPalette.violet,
                            onTap: () => _pickTheme(context, ref, themeMode),
                          ),
                        ],
                      ),
                    ),
                    Gap.h20,

                    // ── App ───────────────────────────────────────
                    FadeSlideIn(
                      index: 2,
                      child: SettingsGroup(
                        title: 'App Settings',
                        tiles: [
                          SettingsTile(
                            icon: Icons.language_rounded,
                            title: 'Language',
                            subtitle: 'Explanations in your native language',
                            value: native.nativeName,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          SettingsTile(
                            icon: Icons.volume_up_rounded,
                            title: 'Sound',
                            subtitle: 'Tutor voice and app sounds',
                            showChevron: false,
                            iconColor: VoixPalette.blue,
                            trailing: Switch(
                              value: user.soundEnabled,
                              onChanged: (v) {
                                Haptic.tap();
                                ref
                                    .read(userControllerProvider.notifier)
                                    .update((u) => u.copyWith(soundEnabled: v));
                              },
                            ),
                          ),
                          SettingsTile(
                            icon: Icons.vibration_rounded,
                            title: 'Haptics',
                            subtitle: 'Vibration feedback on taps',
                            showChevron: false,
                            iconColor: VoixPalette.success,
                            trailing: Switch(
                              value: user.hapticsEnabled,
                              onChanged: (v) {
                                Haptic.enabled = v;
                                if (v) Haptic.tap();
                                ref
                                    .read(userControllerProvider.notifier)
                                    .update(
                                      (u) => u.copyWith(hapticsEnabled: v),
                                    );
                              },
                            ),
                          ),
                          SettingsTile(
                            icon: Icons.info_outline_rounded,
                            title: 'About Voix',
                            subtitle: 'App version and info',
                            iconColor: VoixPalette.cyan,
                            onTap: () => _showAbout(context),
                          ),
                        ],
                      ),
                    ),

                    // Only in a test build. A store release is compiled
                    // without VOIX_TESTING and never shows this.
                    if (BackendConfig.isTestingBuild) ...[
                      Gap.h20,
                      FadeSlideIn(
                        index: 3,
                        child: SettingsGroup(
                          title: 'Testing',
                          tiles: [
                            SettingsTile(
                              icon: Icons.science_rounded,
                              title: 'Backend & premium',
                              subtitle: 'Point this build at your Worker',
                              iconColor: VoixPalette.cyan,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const TestingScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final choice = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Theme', style: context.text.headlineSmall),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(
                  switch (mode) {
                    ThemeMode.dark => Icons.dark_mode_rounded,
                    ThemeMode.light => Icons.light_mode_rounded,
                    ThemeMode.system => Icons.brightness_auto_rounded,
                  },
                  color: mode == current
                      ? context.colors.primary
                      : context.colors.textSecondary,
                ),
                title: Text(
                  switch (mode) {
                    ThemeMode.dark => 'Dark',
                    ThemeMode.light => 'Light',
                    ThemeMode.system => 'Follow system',
                  },
                  style: context.text.titleMedium,
                ),
                trailing: mode == current
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(mode),
              ),
            Gap.h16,
          ],
        ),
      ),
    );

    if (choice == null) return;
    await ref.read(themeControllerProvider.notifier).set(choice);
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VoixWordmark(markSize: 48, fontSize: 30),
            Gap.h16,
            Text(
              // The build is here and not only on the testing screen, because
              // a store release has no testing screen and "which build is
              // that?" is the first question about any bug report.
              'Version 1.0.0 (1) · build ${BuildInfo.commit}',
              style: context.text.labelMedium,
            ),
            Gap.h12,
            Text(
              'Voix helps you speak a new language confidently by having '
              'real conversations with an AI tutor.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Small helper used by the settings sub-screens for a placeholder action
/// whose backend is not part of this build.
void showNotWiredUp(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$what needs a backend — see docs/BACKEND.md.')),
    );
}

/// Shared empty scaffold body used where a settings screen has no data yet.
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        animate: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Gap.xxl),
            children: [
              SettingsAppBar(title: title),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
