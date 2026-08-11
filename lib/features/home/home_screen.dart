import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/xp_bar.dart';
import '../../data/content/lesson_catalog.dart';
import '../../providers/activity_controller.dart';
import '../../providers/user_controller.dart';
import '../learn/lesson_player_screen.dart';
import '../practice/conversation_screen.dart';
import '../practice/scenario_picker_sheet.dart';
import '../learn/learn_page.dart';
import '../shell/app_shell.dart';

/// The daily dashboard: where the learner lands and decides what to do next.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final week = ref.watch(lastSevenDaysProvider);
    final dailyLesson = LessonCatalog.daily(
      DateTime.now(),
      completed: user.completedLessonIds,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // ── Greeting ──────────────────────────────────────────────
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user.name.split(' ').first} 👋',
                          style: context.text.displaySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Gap.h4,
                        Text(
                          'Ready to level up your English?',
                          style: context.text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Gap.w12,
                  StreakPill(days: user.currentStreak),
                ],
              ),
            ),
          ),

          Gap.h20,

          // ── Stat grid ─────────────────────────────────────────────
          FadeSlideIn(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Level',
                          value: '${user.level}',
                          caption: user.levelTitle,
                          captionColor: VoixPalette.blue,
                          trailing: LevelBadge(level: user.level, size: 34),
                        ),
                      ),
                      Gap.w12,
                      Expanded(
                        child: _StatCard(
                          label: 'XP',
                          value: CountUp.format(user.xp),
                          caption: '${CountUp.format(user.xpToNextLevel)} '
                              'to level ${user.level + 1}',
                          child: XpBar(progress: user.levelProgress, height: 6),
                        ),
                      ),
                    ],
                  ),
                  Gap.h12,
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Streak',
                          value: '${user.currentStreak}',
                          unit: user.currentStreak == 1 ? 'day' : 'days',
                          emoji: '🔥',
                        ),
                      ),
                      Gap.w12,
                      Expanded(
                        child: _StatCard(
                          label: "Today's Goal",
                          value: '${user.minutesToday}',
                          unit: '/ ${user.dailyGoalMinutes} mins',
                          icon: Icons.track_changes_rounded,
                          iconColor: VoixPalette.indigo,
                          child: XpBar(
                            progress: user.goalProgress,
                            height: 6,
                            gradient: user.goalMetToday
                                ? VoixGradients.mint
                                : VoixGradients.brandSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Gap.h32,

          // ── Continue learning ─────────────────────────────────────
          FadeSlideIn(
            index: 2,
            child: _SectionRow(
              title: 'Continue Learning',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LearnPage()),
              ),
            ),
          ),
          FadeSlideIn(
            index: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: _DailyPracticeCard(
                title: user.completedLessonIds.contains(dailyLesson.id)
                    ? 'Practice Again'
                    : 'New Daily Practice',
                minutes: dailyLesson.estimatedMinutes,
                subtitle: dailyLesson.title,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LessonPlayerScreen(lesson: dailyLesson),
                  ),
                ),
              ),
            ),
          ),

          Gap.h32,

          // ── Weekly progress ───────────────────────────────────────
          FadeSlideIn(
            index: 4,
            child: _SectionRow(
              title: 'Your Progress',
              onAction: () => AppShell.jumpTo(context, ShellTab.progress),
            ),
          ),
          FadeSlideIn(
            index: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.md, Gap.md, Gap.sm),
                child: WeeklyBarChart(
                  height: 150,
                  showAxis: true,
                  data: [
                    for (final day in week)
                      BarDatum(
                        label: _weekdayInitial(day.date.weekday),
                        value: day.minutes.toDouble(),
                      ),
                  ],
                  selectedIndex: _peakIndex(week.map((d) => d.minutes).toList()),
                ),
              ),
            ),
          ),

          Gap.h32,

          // ── Quick access ──────────────────────────────────────────
          FadeSlideIn(index: 6, child: const _SectionRow(title: 'Quick Access')),
          FadeSlideIn(
            index: 7,
            child: SizedBox(
              height: 118,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                children: [
                  _QuickTile(
                    icon: Icons.mic_rounded,
                    title: 'AI Conversation',
                    caption: 'Talk with your AI tutor',
                    gradient: VoixGradients.brand,
                    onTap: () => _startConversation(context, ref),
                  ),
                  _QuickTile(
                    icon: Icons.menu_book_rounded,
                    title: 'Learn',
                    caption: 'Grammar, vocab & phrases',
                    gradient: VoixGradients.brandSoft,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LearnPage()),
                    ),
                  ),
                  _QuickTile(
                    icon: Icons.description_rounded,
                    title: 'Summary',
                    caption: 'Review your talks',
                    gradient: VoixGradients.violetMagenta,
                    onTap: () => AppShell.jumpTo(context, ShellTab.practice),
                  ),
                  _QuickTile(
                    icon: Icons.insights_rounded,
                    title: 'Progress',
                    caption: 'XP, level & streak',
                    gradient: VoixGradients.mint,
                    onTap: () => AppShell.jumpTo(context, ShellTab.progress),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final scenario = await showScenarioPicker(context, ref);
    if (scenario == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConversationScreen(scenario: scenario)),
    );
  }

  static String _weekdayInitial(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

  /// Highlights the learner's best day so the chart opens with a small win.
  static int? _peakIndex(List<int> values) {
    if (values.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return values[best] == 0 ? null : best;
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.title, this.onAction});
  final String title;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.xs,
                  vertical: Gap.xxs,
                ),
                child: Text(
                  'See All',
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.captionColor,
    this.emoji,
    this.icon,
    this.iconColor,
    this.trailing,
    this.child,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final Color? captionColor;
  final String? emoji;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GlassCard(
      padding: const EdgeInsets.all(Gap.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 15)),
                Gap.w4,
              ] else if (icon != null) ...[
                Icon(icon, size: 15, color: iconColor ?? c.textSecondary),
                Gap.w4,
              ],
              Expanded(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          Gap.h8,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VoixType.stat(26, color: c.textPrimary),
                ),
              ),
              if (unit != null) ...[
                Gap.w4,
                Flexible(
                  child: Text(
                    unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ],
          ),
          if (caption != null) ...[
            Gap.h4,
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                color: captionColor ?? c.textTertiary,
                fontWeight: captionColor != null
                    ? FontWeight.w700
                    : FontWeight.w600,
              ),
            ),
          ],
          if (child != null) ...[Gap.h8, child!],
        ],
      ),
    );
  }
}

class _DailyPracticeCard extends StatelessWidget {
  const _DailyPracticeCard({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AccentCard(
      color: VoixPalette.blue,
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          const IconTile(
            icon: Icons.mic_rounded,
            size: 54,
            gradient: VoixGradients.brand,
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap.h4,
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: c.textTertiary,
                    ),
                    Gap.w4,
                    Text('$minutes min', style: context.text.labelSmall),
                    Gap.w12,
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: VoixPalette.cyan,
                    ),
                    Gap.w4,
                    Flexible(
                      child: Text(
                        'AI-picked for you',
                        style: context.text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Gap.h8,
                Text(
                  subtitle,
                  style: context.text.bodySmall
                      ?.copyWith(color: c.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Gap.w12,
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: VoixGradients.brandSoft,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: VoixPalette.blue.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Gap.sm),
      child: SizedBox(
        width: 140,
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.all(Gap.sm + 2),
          semanticLabel: '$title. $caption',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconTile(icon: icon, gradient: gradient, size: 36),
              const Spacer(),
              Text(
                title,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: context.text.labelSmall?.copyWith(fontSize: 10.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
