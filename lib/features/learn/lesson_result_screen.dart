import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/energy_orb.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/voix_button.dart';
import '../../data/models/lesson.dart';
import '../../providers/activity_controller.dart';
import '../../providers/user_controller.dart';

/// End-of-lesson celebration. Commits the XP, streak and activity record on
/// first build, then reports what the learner gained.
class LessonResultScreen extends ConsumerStatefulWidget {
  const LessonResultScreen({
    super.key,
    required this.lesson,
    required this.result,
  });

  final Lesson lesson;
  final LessonResult result;

  @override
  ConsumerState<LessonResultScreen> createState() => _LessonResultScreenState();
}

class _LessonResultScreenState extends ConsumerState<LessonResultScreen> {
  PracticeReward? _reward;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _commit());
  }

  Future<void> _commit() async {
    if (_committed) return;
    _committed = true;

    final minutes = (widget.result.durationSeconds / 60)
        .ceil()
        .clamp(1, widget.lesson.estimatedMinutes * 3);

    final reward =
        await ref.read(userControllerProvider.notifier).registerPractice(
              PracticeOutcome(
                xpEarned: widget.result.xpEarned,
                minutes: minutes,
                lessons: 1,
                lessonId: widget.lesson.id,
                // Vocabulary and flashcard lessons are where new words come
                // from; other categories drill what the learner already knows.
                wordsLearned: widget.lesson.category == LessonCategory.vocabulary ||
                        widget.lesson.category == LessonCategory.slang
                    ? widget.result.correct
                    : 0,
              ),
            );

    await ref.read(activityControllerProvider.notifier).record(
          minutes: minutes,
          xp: widget.result.xpEarned,
          lessons: 1,
        );

    if (!mounted) return;
    Haptic.success();
    setState(() => _reward = reward);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final result = widget.result;
    final accuracy = (result.accuracy * 100).round();
    final perfect = result.correct == result.total;

    final headline = perfect
        ? 'Perfect run!'
        : (result.passed ? 'Lesson complete!' : 'Good try!');
    final blurb = perfect
        ? 'Every single answer correct. That is mastery.'
        : (result.passed
            ? 'Solid work — you are getting more confident.'
            : 'Review the explanations and try this one again.');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: AuroraBackground(
          intensity: 1.3,
          colors: perfect
              ? const [VoixPalette.gold, VoixPalette.streak]
              : const [VoixPalette.blue, VoixPalette.violet],
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    child: Column(
                      children: [
                        Gap.h32,
                        FadeSlideIn(
                          offset: 0,
                          child: SizedBox(
                            height: 170,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                EnergyOrb(
                                  size: 170,
                                  energy: 0.9,
                                  amplitude: 0.45,
                                  colors: perfect
                                      ? const [
                                          VoixPalette.gold,
                                          VoixPalette.streak,
                                          VoixPalette.magenta,
                                        ]
                                      : const [
                                          VoixPalette.cyan,
                                          VoixPalette.blue,
                                          VoixPalette.violet,
                                        ],
                                ),
                                Text(
                                  perfect ? '🏆' : '🎉',
                                  style: const TextStyle(fontSize: 54),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Gap.h24,
                        FadeSlideIn(
                          index: 1,
                          child: GradientText(
                            headline,
                            style: context.text.displaySmall,
                            gradient: perfect
                                ? VoixGradients.gold
                                : VoixGradients.brand,
                          ),
                        ),
                        Gap.h8,
                        FadeSlideIn(
                          index: 2,
                          child: Text(
                            blurb,
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium,
                          ),
                        ),
                        Gap.h32,

                        // ── Score ─────────────────────────────────
                        FadeSlideIn(
                          index: 3,
                          child: GlassCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: ScoreRing(
                                    score: accuracy,
                                    label: 'Accuracy',
                                    size: 78,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 60,
                                  color: c.border,
                                ),
                                Expanded(
                                  child: _Metric(
                                    value: '${result.correct}/${result.total}',
                                    label: 'Correct',
                                    icon: Icons.check_circle_outline_rounded,
                                    color: c.success,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 60,
                                  color: c.border,
                                ),
                                Expanded(
                                  child: _Metric(
                                    value: '+${result.xpEarned}',
                                    label: 'XP earned',
                                    icon: Icons.bolt_rounded,
                                    color: c.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Rewards ───────────────────────────────
                        if (_reward != null) ...[
                          if (_reward!.leveledUp) ...[
                            Gap.h12,
                            FadeSlideIn(
                              index: 4,
                              child: _RewardRow(
                                emoji: '⭐',
                                title: 'Level ${_reward!.newLevel} reached',
                                subtitle: 'You are now ${_levelTitle(ref)}',
                                color: VoixPalette.gold,
                              ),
                            ),
                          ],
                          if (_reward!.streakIncreased) ...[
                            Gap.h12,
                            FadeSlideIn(
                              index: 5,
                              child: _RewardRow(
                                emoji: '🔥',
                                title: '${_reward!.streak} day streak',
                                subtitle: 'Come back tomorrow to keep it alive',
                                color: VoixPalette.streak,
                              ),
                            ),
                          ],
                          for (final achievement in _reward!.unlocked) ...[
                            Gap.h12,
                            FadeSlideIn(
                              index: 6,
                              child: _RewardRow(
                                emoji: achievement.emoji,
                                title: achievement.title,
                                subtitle: achievement.description,
                                color: VoixPalette.violet,
                              ),
                            ),
                          ],
                        ],
                        Gap.h24,
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    0,
                    Gap.page,
                    Gap.lg,
                  ),
                  child: Column(
                    children: [
                      VoixButton(
                        label: 'Continue',
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Gap.h8,
                      VoixButton.ghost(
                        label: 'Retry lesson',
                        expand: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _levelTitle(WidgetRef ref) =>
      ref.read(userControllerProvider)?.levelTitle ?? 'a Voix learner';
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        Gap.h8,
        Text(
          value,
          style: VoixType.stat(19, color: context.colors.textPrimary),
        ),
        Gap.h4,
        Text(label, style: context.text.labelSmall),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      color: color,
      padding: const EdgeInsets.all(Gap.sm + 2),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.text.labelSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
