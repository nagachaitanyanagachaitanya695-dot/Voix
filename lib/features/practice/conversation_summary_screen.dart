import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/voix_button.dart';
import '../../core/widgets/xp_bar.dart';
import '../../data/models/conversation.dart';
import '../../providers/app_providers.dart';
import '../../providers/session_controller.dart';
import '../../providers/user_controller.dart';
import 'scenario_picker_sheet.dart';
import 'conversation_screen.dart';

/// The post-conversation coaching report.
///
/// Structured as four numbered sections — corrections, vocabulary, phrases,
/// slang — above the scores, so the learner reads *what to fix* before *how
/// they were graded*.
class ConversationSummaryScreen extends ConsumerWidget {
  const ConversationSummaryScreen({
    super.key,
    required this.session,
    this.reward,
  });

  final ConversationSession session;

  /// Present when arriving straight from a finished conversation; absent when
  /// the report is reopened from history.
  final PracticeReward? reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final summary = session.summary;
    final user = ref.watch(userControllerProvider);

    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Summary')),
        body: const Center(child: Text('This conversation has no report yet.')),
      );
    }

    return Scaffold(
      body: AuroraBackground(
        animate: false,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.xxl),
            children: [
              // ── Header ────────────────────────────────────────────
              FadeSlideIn(
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => Navigator.of(context).pop(),
                      scale: 0.9,
                      semanticLabel: 'Back',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Gap.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'AI Speaking Coach',
                                  style: context.text.headlineSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Gap.w4,
                              const Text('✨', style: TextStyle(fontSize: 15)),
                            ],
                          ),
                          Text(
                            'Feedback from ${session.scenarioTitle}',
                            style: context.text.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Gap.w8,
                    if (user != null) StreakPill(days: user.currentStreak),
                  ],
                ),
              ),

              Gap.h16,

              // ── Reward banner ─────────────────────────────────────
              if (reward != null)
                FadeSlideIn(
                  index: 1,
                  child: _RewardBanner(reward: reward!),
                ),
              if (reward != null) Gap.h16,

              // ── Tally ─────────────────────────────────────────────
              FadeSlideIn(
                index: 2,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm + 2),
                  child: Row(
                    children: [
                      _Tally(
                        icon: Icons.check_circle_outline_rounded,
                        color: c.success,
                        value: summary.corrections.length,
                        label: 'Grammar\nCorrections',
                      ),
                      _TallyDivider(color: c.border),
                      _Tally(
                        icon: Icons.menu_book_rounded,
                        color: VoixPalette.violet,
                        value: summary.vocabulary.length,
                        label: 'New\nWords',
                      ),
                      _TallyDivider(color: c.border),
                      _Tally(
                        icon: Icons.forum_rounded,
                        color: VoixPalette.blue,
                        value: summary.phrases.length,
                        label: 'Useful\nPhrases',
                      ),
                      _TallyDivider(color: c.border),
                      _Tally(
                        icon: Icons.emoji_emotions_rounded,
                        color: VoixPalette.magenta,
                        value: summary.slang.length,
                        label: 'Slangs\nLearned',
                      ),
                    ],
                  ),
                ),
              ),

              Gap.h16,

              // ── Scores ────────────────────────────────────────────
              FadeSlideIn(
                index: 3,
                child: GlassCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ScoreRing(
                              score: summary.fluencyScore,
                              label: 'Fluency',
                              size: 74,
                            ),
                          ),
                          Expanded(
                            child: ScoreRing(
                              score: summary.pronunciationScore,
                              label: 'Pronunciation',
                              size: 74,
                            ),
                          ),
                          Expanded(
                            child: ScoreRing(
                              score: summary.confidenceScore,
                              label: 'Confidence',
                              size: 74,
                            ),
                          ),
                        ],
                      ),
                      if (summary.encouragement.isNotEmpty) ...[
                        Gap.h16,
                        Container(
                          padding: const EdgeInsets.all(Gap.sm + 2),
                          decoration: BoxDecoration(
                            color: c.primary.withValues(alpha: 0.09),
                            borderRadius: Radii.rSm,
                            border: Border.all(
                              color: c.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: c.primary,
                              ),
                              Gap.w8,
                              Expanded(
                                child: Text(
                                  summary.encouragement,
                                  style: context.text.bodySmall?.copyWith(
                                    color: c.textPrimary,
                                    height: 1.45,
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
              ),

              // ── 1. Corrections ────────────────────────────────────
              if (summary.corrections.isNotEmpty) ...[
                Gap.h24,
                FadeSlideIn(
                  index: 4,
                  child: _NumberedHeader(
                    number: 1,
                    color: VoixPalette.success,
                    title: 'Grammar Corrections',
                    badge: '${summary.corrections.length} '
                        '${summary.corrections.length == 1 ? "fix" : "fixes"}',
                  ),
                ),
                Gap.h12,
                FadeSlideIn(
                  index: 5,
                  child: _CorrectionCarousel(
                    corrections: summary.corrections,
                  ),
                ),
              ],

              // ── 2. Vocabulary ─────────────────────────────────────
              if (summary.vocabulary.isNotEmpty) ...[
                Gap.h24,
                FadeSlideIn(
                  index: 6,
                  child: _NumberedHeader(
                    number: 2,
                    color: VoixPalette.violet,
                    title: 'Vocabulary',
                    badge: '${summary.vocabulary.length} new words',
                  ),
                ),
                Gap.h12,
                FadeSlideIn(
                  index: 7,
                  child: SizedBox(
                    height: 78,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: summary.vocabulary.length,
                      separatorBuilder: (_, __) => Gap.w8,
                      itemBuilder: (context, i) =>
                          _VocabChip(item: summary.vocabulary[i]),
                    ),
                  ),
                ),
              ],

              // ── 3. Phrases ────────────────────────────────────────
              if (summary.phrases.isNotEmpty) ...[
                Gap.h24,
                FadeSlideIn(
                  index: 8,
                  child: _NumberedHeader(
                    number: 3,
                    color: VoixPalette.blue,
                    title: 'Useful Phrases',
                    badge: '${summary.phrases.length} phrases',
                  ),
                ),
                Gap.h12,
                FadeSlideIn(
                  index: 9,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm + 2,
                      vertical: Gap.xxs,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < summary.phrases.length; i++) ...[
                          if (i > 0) Divider(color: c.border, height: 1),
                          _PhraseRow(phrase: summary.phrases[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // ── 4. Slang ──────────────────────────────────────────
              if (summary.slang.isNotEmpty) ...[
                Gap.h24,
                FadeSlideIn(
                  index: 10,
                  child: _NumberedHeader(
                    number: 4,
                    color: VoixPalette.magenta,
                    title: 'Gen-Z Slang',
                    badge: '${summary.slang.length} new',
                  ),
                ),
                Gap.h12,
                for (final term in summary.slang)
                  FadeSlideIn(
                    index: 11,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Gap.xs),
                      child: _SlangCard(term: term),
                    ),
                  ),
              ],

              Gap.h32,

              // ── CTA ───────────────────────────────────────────────
              FadeSlideIn(
                index: 12,
                child: VoixButton(
                  label: 'Practice Again',
                  icon: Icons.mic_rounded,
                  onPressed: () async {
                    final scenario = await showScenarioPicker(context, ref);
                    if (scenario == null || !context.mounted) return;
                    await Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ConversationScreen(scenario: scenario),
                      ),
                    );
                  },
                ),
              ),
              Gap.h12,
              FadeSlideIn(
                index: 13,
                child: VoixButton.secondary(
                  label: 'Back to Practice',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reward ─────────────────────────────────────────────────────────────────

class _RewardBanner extends StatelessWidget {
  const _RewardBanner({required this.reward});
  final PracticeReward reward;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AccentCard(
      color: reward.leveledUp ? VoixPalette.gold : VoixPalette.blue,
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(
                icon: reward.leveledUp
                    ? Icons.military_tech_rounded
                    : Icons.bolt_rounded,
                gradient: reward.leveledUp
                    ? VoixGradients.gold
                    : VoixGradients.brandSoft,
                size: 46,
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.leveledUp
                          ? 'Level ${reward.newLevel} unlocked!'
                          : 'Nice work!',
                      style: context.text.titleMedium,
                    ),
                    Text(
                      reward.streakIncreased
                          ? '${reward.streak} day streak — keep it going'
                          : 'Progress saved',
                      style: context.text.labelSmall,
                    ),
                  ],
                ),
              ),
              CountUp(
                value: reward.xpEarned,
                prefix: '+',
                suffix: ' XP',
                style: VoixType.stat(20, color: c.primary),
              ),
            ],
          ),
          if (reward.unlocked.isNotEmpty) ...[
            Gap.h12,
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 15, color: c.gold),
                Gap.w8,
                Expanded(
                  child: Text(
                    reward.unlocked.length == 1
                        ? 'Achievement unlocked: ${reward.unlocked.first.title}'
                        : '${reward.unlocked.length} achievements unlocked!',
                    style: context.text.labelSmall?.copyWith(color: c.gold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tally row ──────────────────────────────────────────────────────────────

class _Tally extends StatelessWidget {
  const _Tally({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          Gap.h4,
          CountUp(
            value: value,
            style: VoixType.stat(20, color: context.colors.textPrimary),
            separator: false,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(fontSize: 9.5, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _TallyDivider extends StatelessWidget {
  const _TallyDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: color);
}

// ── Section header ─────────────────────────────────────────────────────────

class _NumberedHeader extends StatelessWidget {
  const _NumberedHeader({
    required this.number,
    required this.color,
    required this.title,
    required this.badge,
  });

  final int number;
  final Color color;
  final String title;
  final String badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NumberBadge(number: number, color: color),
        Gap.w8,
        Expanded(
          child: Text(
            title,
            style: context.text.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: Radii.rXs,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            badge,
            style: context.text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Corrections ────────────────────────────────────────────────────────────

class _CorrectionCarousel extends ConsumerStatefulWidget {
  const _CorrectionCarousel({required this.corrections});
  final List<Correction> corrections;

  @override
  ConsumerState<_CorrectionCarousel> createState() =>
      _CorrectionCarouselState();
}

class _CorrectionCarouselState extends ConsumerState<_CorrectionCarousel> {
  final _pager = PageController(viewportFraction: 0.995);
  int _page = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        SizedBox(
          // Sized to the tallest realistic card so paging does not resize the
          // surrounding scroll view.
          height: 210,
          child: PageView.builder(
            controller: _pager,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.corrections.length,
            itemBuilder: (context, i) =>
                _CorrectionCard(correction: widget.corrections[i]),
          ),
        ),
        if (widget.corrections.length > 1) ...[
          Gap.h8,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.corrections.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: Motion.base,
                curve: Motion.enter,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? c.primary : c.border,
                  borderRadius: Radii.rPill,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _CorrectionCard extends ConsumerWidget {
  const _CorrectionCard({required this.correction});
  final Correction correction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    Widget line(IconData icon, Color color, String label, String text,
        {Color? textColor}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: context.text.bodyMedium?.copyWith(
                    color: textColor ?? c.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(
            Icons.cancel_outlined,
            c.danger,
            'Your sentence',
            correction.original,
          ),
          Gap.h12,
          line(
            Icons.check_circle_outline_rounded,
            c.success,
            'Better sentence',
            correction.corrected,
            textColor: c.success,
          ),
          Gap.h12,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 17, color: c.warning),
                Gap.w8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Explanation', style: context.text.labelSmall),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          correction.explanation,
                          style: context.text.bodySmall?.copyWith(height: 1.45),
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap.w8,
                _PlayButton(text: correction.corrected),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Speaks a snippet aloud using the tutor's configured voice.
class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.text, this.size = 40});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return Pressable(
      onTap: () => ref.read(speechServiceProvider).speak(text),
      scale: 0.88,
      semanticLabel: 'Listen to "$text"',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: c.primary.withValues(alpha: 0.35)),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          size: size * 0.55,
          color: c.primary,
        ),
      ),
    );
  }
}

// ── Vocabulary ─────────────────────────────────────────────────────────────

class _VocabChip extends StatelessWidget {
  const _VocabChip({required this.item});
  final VocabUpgrade item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.rSm,
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.simple,
            style: context.text.labelMedium?.copyWith(color: c.textTertiary),
          ),
          Gap.h4,
          Container(width: 26, height: 1, color: c.border),
          Gap.h4,
          GradientText(
            item.better,
            style: context.text.titleSmall,
            gradient: VoixGradients.violetMagenta,
          ),
        ],
      ),
    );
  }
}

// ── Phrases ────────────────────────────────────────────────────────────────

class _PhraseRow extends ConsumerWidget {
  const _PhraseRow({required this.phrase});
  final String phrase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final saved = ref.watch(savedPhrasesProvider).contains(phrase);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs + 2),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 15, color: c.primary),
          Gap.w12,
          Expanded(
            child: Text(phrase, style: context.text.bodyMedium?.copyWith(
              color: c.textPrimary,
            )),
          ),
          _PlayButton(text: phrase, size: 32),
          Gap.w4,
          Pressable(
            onTap: () =>
                ref.read(savedPhrasesProvider.notifier).toggle(phrase),
            scale: 0.85,
            semanticLabel: saved ? 'Remove from saved' : 'Save phrase',
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                saved ? Icons.star_rounded : Icons.star_border_rounded,
                size: 20,
                color: saved ? c.gold : c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slang ──────────────────────────────────────────────────────────────────

class _SlangCard extends StatelessWidget {
  const _SlangCard({required this.term});
  final SlangTerm term;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(Gap.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VoixPalette.magenta.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(term.emoji, style: const TextStyle(fontSize: 18)),
          ),
          Gap.w12,
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        term.term,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Gap.w4,
                    _PlayButton(text: term.term, size: 26),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Meaning: ${term.meaning}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Gap.w8,
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example',
                  style: context.text.labelSmall?.copyWith(
                    color: VoixPalette.magenta,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  term.example,
                  style: context.text.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
