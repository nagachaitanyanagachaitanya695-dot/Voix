import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/menu_button.dart';
import '../../core/widgets/mic_button.dart';
import '../../core/widgets/staggered.dart';
import '../../data/models/user_profile.dart';
import '../../providers/session_controller.dart';
import '../../providers/user_controller.dart';
import '../learn/learn_page.dart';
import '../onboarding/widgets/option_tile.dart';
import '../profile/premium_screen.dart';
import '../profile/settings_screen.dart';
import '../shell/app_shell.dart';
import 'conversation_screen.dart';
import 'conversation_summary_screen.dart';
import 'live_call_screen.dart';
import 'scenario_picker_sheet.dart';

/// The launchpad for spoken practice: pick a register, then start talking.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final lastSummary = ref.watch(latestSummarisedSessionProvider);

    // A live call is the app's real shape: you talk, the tutor talks back,
    // either of you can cut in. It needs a subscription and a deployed
    // backend, so the main button only takes that route when both are true —
    // it must never dead-end into a screen explaining what is missing.
    final canCallLive = user.isPro && BackendConfig.isConfigured;

    Future<void> start() async {
      final scenario = await showScenarioPicker(context, ref);
      if (scenario == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => canCallLive
              ? LiveCallScreen(scenario: scenario)
              : ConversationScreen(scenario: scenario),
        ),
      );
    }

    /// Live speech-to-speech — a Premium feature. Non-subscribers get the
    /// paywall rather than a call the server would refuse anyway; subscribers
    /// on a build with no backend reach the call screen, which explains that
    /// it is not configured.
    Future<void> startLiveCall() async {
      if (!user.isPro) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        );
        return;
      }
      final scenario = await showScenarioPicker(context, ref);
      if (scenario == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveCallScreen(scenario: scenario)),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // ── Header ────────────────────────────────────────────────
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
              child: Row(
                children: [
                  MenuButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text('Practice', style: context.text.displaySmall),
                  ),
                  if (user.isPro)
                    const _ProBadge()
                  else
                    _UpgradeChip(
                      onTap: () => AppShell.jumpTo(context, ShellTab.profile),
                    ),
                ],
              ),
            ),
          ),

          Gap.h24,

          // ── Mode ──────────────────────────────────────────────────
          FadeSlideIn(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: Gap.page, bottom: Gap.sm),
              child: Text('Choose Mode', style: context.text.titleLarge),
            ),
          ),
          FadeSlideIn(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceCard(
                      title: LearningMode.standard.label,
                      subtitle: LearningMode.standard.description,
                      emoji: LearningMode.standard.emoji,
                      selected: user.mode == LearningMode.standard,
                      height: 118,
                      onTap: () {
                        Haptic.light();
                        ref
                            .read(userControllerProvider.notifier)
                            .update((u) => u.copyWith(
                                  mode: LearningMode.standard,
                                ));
                      },
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: ChoiceCard(
                      title: LearningMode.genZ.label,
                      subtitle: LearningMode.genZ.description,
                      emoji: LearningMode.genZ.emoji,
                      accent: VoixPalette.magenta,
                      selected: user.mode == LearningMode.genZ,
                      height: 118,
                      onTap: () {
                        Haptic.light();
                        ref
                            .read(userControllerProvider.notifier)
                            .update((u) => u.copyWith(mode: LearningMode.genZ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Gap.h24,

          // ── Quick start ───────────────────────────────────────────
          FadeSlideIn(
            index: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: Gap.page, bottom: Gap.sm),
              child: Text('Quick Start', style: context.text.titleLarge),
            ),
          ),
          FadeSlideIn(
            index: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: AccentCard(
                color: VoixPalette.blue,
                onTap: start,
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    const IconTile(
                      icon: Icons.mic_rounded,
                      size: 52,
                      gradient: VoixGradients.brand,
                    ),
                    Gap.w16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            canCallLive
                                ? 'Live AI Conversation'
                                : 'AI Voice Conversation',
                            style: context.text.titleMedium,
                          ),
                          Gap.h4,
                          Text(
                            canCallLive
                                ? 'Speak and be answered straight away'
                                : 'Talk with your AI tutor and improve speaking',
                            style: context.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: c.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Gap.h12,

          // ── Live call ─────────────────────────────────────────────
          // Only when the main button is *not* already a live call, so this is
          // the route in rather than a duplicate. It stays visible on a build
          // with no backend on purpose: hiding it made the feature impossible
          // to discover, so tapping explains what is missing instead.
          if (!canCallLive)
            FadeSlideIn(
              index: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: AccentCard(
                  color: VoixPalette.violet,
                  onTap: startLiveCall,
                  padding: const EdgeInsets.all(Gap.md),
                  child: Row(
                    children: [
                      const IconTile(
                        icon: Icons.graphic_eq_rounded,
                        size: 52,
                        gradient: VoixGradients.violetMagenta,
                      ),
                      Gap.w16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Live Conversation',
                                    style: context.text.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!user.isPro) ...[
                                  Gap.w8,
                                  const _PremiumTag(),
                                ],
                              ],
                            ),
                            Gap.h4,
                            Text(
                              'Talk like a phone call — no recording, no '
                              'sending. Interrupt any time.',
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                    ],
                  ),
                ),
              ),
            ),

          Gap.h16,

          // ── Feature tiles ─────────────────────────────────────────
          FadeSlideIn(
            index: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Column(
                children: [
                  // IntrinsicHeight bounds the row so `stretch` can equalise
                  // the two cards; without it, stretch inside a scroll view
                  // asks for infinite height.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FeatureTile(
                            icon: Icons.menu_book_rounded,
                            gradient: VoixGradients.brandSoft,
                            title: 'Grammar, Vocabulary,\nPhrases & Slang',
                            caption:
                                'Get real-time corrections and smart suggestions',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LearnPage(),
                              ),
                            ),
                          ),
                        ),
                        Gap.w12,
                        Expanded(
                          child: _FeatureTile(
                            icon: Icons.description_rounded,
                            gradient: VoixGradients.violetMagenta,
                            title: 'Conversation\nSummary',
                            caption: lastSummary == null
                                ? 'Finish a chat to see your report'
                                : 'Review & improve your talks',
                            onTap: lastSummary == null
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ConversationSummaryScreen(
                                          session: lastSummary,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.h12,
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FeatureTile(
                            icon: Icons.insights_rounded,
                            gradient: VoixGradients.mint,
                            title: 'Progress',
                            caption: 'Track XP, level, streak & history',
                            onTap: () =>
                                AppShell.jumpTo(context, ShellTab.progress),
                          ),
                        ),
                        Gap.w12,
                        Expanded(
                          child: _FeatureTile(
                            icon: Icons.settings_rounded,
                            gradient: VoixGradients.flame,
                            title: 'Settings',
                            caption: 'Profile, voice, language & more',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Gap.h32,

          // ── Big mic ───────────────────────────────────────────────
          FadeSlideIn(
            index: 6,
            child: Column(
              children: [
                MicButton(onTap: start, size: 88),
                Gap.h8,
                Text(
                  canCallLive
                      ? 'Tap to Start a Live Call'
                      : 'Tap to Start Speaking',
                  style: context.text.titleSmall?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "Premium" marker on a locked feature.
class _PremiumTag extends StatelessWidget {
  const _PremiumTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 2),
      decoration: BoxDecoration(
        color: VoixPalette.violet.withValues(alpha: 0.18),
        borderRadius: Radii.rPill,
      ),
      child: Text(
        'Premium',
        style: context.text.labelSmall?.copyWith(
          color: VoixPalette.violet,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 7),
      decoration: BoxDecoration(
        color: c.gold.withValues(alpha: 0.14),
        borderRadius: Radii.rPill,
        border: Border.all(color: c.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 13)),
          Gap.w4,
          Text(
            'Pro',
            style: context.text.labelMedium?.copyWith(
              color: c.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeChip extends StatelessWidget {
  const _UpgradeChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: Radii.pill,
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 7),
      semanticLabel: 'Upgrade to Voix Pro',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 13)),
          Gap.w4,
          Text(
            'Go Pro',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final Gradient gradient;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Gap.sm + 2),
        semanticLabel: '${title.replaceAll('\n', ' ')}. $caption',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, gradient: gradient, size: 36),
            Gap.h12,
            Text(
              title,
              style: context.text.titleSmall?.copyWith(height: 1.3),
            ),
            Gap.h4,
            Text(
              caption,
              style: context.text.labelSmall?.copyWith(
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
