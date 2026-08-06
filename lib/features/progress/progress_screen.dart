import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/xp_bar.dart';
import '../../data/models/achievement.dart';
import '../../data/models/conversation.dart';
import '../../data/models/daily_activity.dart';
import '../../data/models/user_profile.dart';
import '../../providers/activity_controller.dart';
import '../../providers/session_controller.dart';
import '../../providers/user_controller.dart';
import '../practice/conversation_summary_screen.dart';
import 'achievements_screen.dart';

/// Which window the activity chart is showing.
enum _Range {
  thisWeek('This Week'),
  lastWeek('Last Week'),
  last30('Last 30 Days');

  const _Range(this.label);
  final String label;
}

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  _Range _range = _Range.thisWeek;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final activity = ref.watch(activityControllerProvider);
    final sessions = ref.watch(sessionHistoryProvider);
    final achievements = ref.watch(achievementsProvider);

    final bars = _barsFor(_range, activity);

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
                  Expanded(
                    child: Text('Progress', style: context.text.displaySmall),
                  ),
                  StreakPill(days: user.currentStreak, showLabel: true),
                ],
              ),
            ),
          ),

          Gap.h20,

          // ── Level ─────────────────────────────────────────────────
          FadeSlideIn(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GlassCard(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  children: [
                    LevelBadge(level: user.level, size: 62),
                    Gap.w16,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('Level ', style: context.text.labelMedium),
                              Text(
                                '${user.level}',
                                style: VoixType.stat(
                                  24,
                                  color: c.textPrimary,
                                ),
                              ),
                              Gap.w8,
                              Flexible(
                                child: Text(
                                  user.levelTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelMedium?.copyWith(
                                    color: VoixPalette.violet,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Gap.h8,
                          Row(
                            children: [
                              Text(
                                CountUp.format(user.xp),
                                style: VoixType.stat(19, color: c.textPrimary),
                              ),
                              Gap.w4,
                              Text(
                                'XP',
                                style: context.text.labelSmall?.copyWith(
                                  color: VoixPalette.violet,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  '${CountUp.format(user.xpToNextLevel)} to '
                                  'Level ${user.level + 1}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall,
                                ),
                              ),
                            ],
                          ),
                          Gap.h8,
                          XpBar(progress: user.levelProgress, height: 9),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Gap.h12,

          // ── Lifetime stats ────────────────────────────────────────
          FadeSlideIn(
            index: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Row(
                  children: [
                    _LifetimeStat(
                      icon: Icons.forum_rounded,
                      color: VoixPalette.violet,
                      value: user.totalConversations,
                      label: 'Conversations',
                    ),
                    Container(width: 1, height: 52, color: c.border),
                    _LifetimeStat(
                      icon: Icons.schedule_rounded,
                      color: VoixPalette.success,
                      value: user.totalMinutes,
                      label: 'Minutes Practised',
                    ),
                    Container(width: 1, height: 52, color: c.border),
                    _LifetimeStat(
                      icon: Icons.menu_book_rounded,
                      color: VoixPalette.blue,
                      value: user.wordsLearned,
                      label: 'New Words Learned',
                    ),
                  ],
                ),
              ),
            ),
          ),

          Gap.h24,

          // ── Activity chart ────────────────────────────────────────
          FadeSlideIn(
            index: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(
                  Gap.sm,
                  Gap.md,
                  Gap.md,
                  Gap.sm,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: Gap.xs),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weekly Activity',
                              style: context.text.titleMedium,
                            ),
                          ),
                          _RangeMenu(
                            value: _range,
                            onChanged: (r) => setState(() => _range = r),
                          ),
                        ],
                      ),
                    ),
                    Gap.h16,
                    WeeklyBarChart(
                      key: ValueKey(_range),
                      data: bars,
                      height: 170,
                      selectedIndex: _peakIndex(bars),
                    ),
                    Gap.h8,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: VoixPalette.indigo,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Gap.w8,
                        Text(
                          'Minutes Practised',
                          style: context.text.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Gap.h24,

          // ── Recent conversations ──────────────────────────────────
          FadeSlideIn(
            index: 4,
            child: SectionHeader(
              title: 'Recent Conversations',
              actionLabel: sessions.isEmpty ? null : 'View All',
              onAction: sessions.isEmpty ? null : () {},
            ),
          ),
          FadeSlideIn(
            index: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: sessions.isEmpty
                  ? _EmptyCard(
                      icon: Icons.mic_none_rounded,
                      title: 'No conversations yet',
                      caption:
                          'Start a practice conversation and it will show up here.',
                    )
                  : GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.sm + 2,
                        vertical: Gap.xxs,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0;
                              i < sessions.length.clamp(0, 3);
                              i++) ...[
                            if (i > 0) Divider(color: c.border, height: 1),
                            _SessionRow(session: sessions[i]),
                          ],
                        ],
                      ),
                    ),
            ),
          ),

          Gap.h24,

          // ── Achievements ──────────────────────────────────────────
          FadeSlideIn(
            index: 6,
            child: SectionHeader(
              title: 'Achievements',
              actionLabel: 'View All',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              ),
            ),
          ),
          FadeSlideIn(
            index: 7,
            child: SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                itemCount: achievements.length.clamp(0, 6),
                separatorBuilder: (_, __) => Gap.w12,
                itemBuilder: (context, i) => SizedBox(
                  width: 132,
                  child: AchievementCard(
                    achievement: achievements[i],
                    user: user,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the chart series for the selected range.
  List<BarDatum> _barsFor(_Range range, Map<String, DailyActivity> activity) {
    DailyActivity at(DateTime day) {
      final n = DailyActivity.normalise(day);
      return activity[DailyActivity.dayKey(n)] ?? DailyActivity(date: n);
    }

    final today = DailyActivity.normalise(DateTime.now());

    switch (range) {
      case _Range.thisWeek:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          return BarDatum(
            label: _weekdayShort(day.weekday),
            value: at(day).minutes.toDouble(),
          );
        });

      case _Range.lastWeek:
        final monday = today
            .subtract(Duration(days: today.weekday - 1))
            .subtract(const Duration(days: 7));
        return List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          return BarDatum(
            label: _weekdayShort(day.weekday),
            value: at(day).minutes.toDouble(),
          );
        });

      case _Range.last30:
        // 30 individual bars would be unreadable on a phone, so the month is
        // bucketed into six five-day groups.
        return List.generate(6, (i) {
          var total = 0;
          for (var d = 0; d < 5; d++) {
            final day = today.subtract(Duration(days: (5 - i) * 5 - d));
            total += at(day).minutes;
          }
          return BarDatum(label: '${i * 5 + 1}', value: total.toDouble());
        });
    }
  }

  static String _weekdayShort(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  static int? _peakIndex(List<BarDatum> bars) {
    if (bars.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < bars.length; i++) {
      if (bars[i].value > bars[best].value) best = i;
    }
    return bars[best].value == 0 ? null : best;
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────────

class _RangeMenu extends StatelessWidget {
  const _RangeMenu({required this.value, required this.onChanged});
  final _Range value;
  final ValueChanged<_Range> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<_Range>(
      initialValue: value,
      onSelected: onChanged,
      color: c.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.rSm,
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (_) => [
        for (final r in _Range.values)
          PopupMenuItem(
            value: r,
            height: 40,
            child: Text(r.label, style: context.text.bodyMedium),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.sm,
          vertical: Gap.xs,
        ),
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceHigh : c.bgAlt,
          borderRadius: Radii.rSm,
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.label,
              style: context.text.labelMedium
                  ?.copyWith(color: c.textSecondary),
            ),
            Gap.w4,
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LifetimeStat extends StatelessWidget {
  const _LifetimeStat({
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          Gap.h8,
          CountUp(
            value: value,
            style: VoixType.stat(21, color: context.colors.textPrimary),
          ),
          Gap.h4,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.xxs),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: context.text.labelSmall?.copyWith(
                fontSize: 10,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});
  final ConversationSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final score = session.summary?.overallScore ?? 0;
    final tint = score >= 80
        ? c.success
        : (score >= 60 ? c.primary : VoixPalette.violet);

    // Pressable rather than InkWell: it matches every other tappable surface
    // in the app and carries no Material-ancestor requirement.
    return Pressable(
      onTap: session.summary == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ConversationSummaryScreen(session: session),
                ),
              ),
      scale: 0.99,
      semanticLabel: '${session.scenarioTitle}, '
          '${(session.durationSeconds / 60).ceil()} minutes',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.isDark ? c.surfaceHigh : c.bgAlt,
                shape: BoxShape.circle,
              ),
              child: Text(session.emoji, style: const TextStyle(fontSize: 18)),
            ),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.scenarioTitle,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_relativeDay(session.startedAt)}  •  '
                    '${(session.durationSeconds / 60).ceil()} min',
                    style: context.text.labelSmall,
                  ),
                ],
              ),
            ),
            if (session.summary != null)
              Text(
                '$score%',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            Gap.w4,
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeDay(DateTime at) {
    final today = DailyActivity.normalise(DateTime.now());
    final day = DailyActivity.normalise(at);
    final diff = today.difference(day).inDays;

    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final period = at.hour < 12 ? 'AM' : 'PM';
    final time = '$hour:$minute $period';

    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    if (diff < 7) return '$diff days ago';
    return '${day.day}/${day.month}/${day.year}';
  }
}

/// Achievement tile — shared by the Progress carousel and the full grid.
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.user,
  });

  final Achievement achievement;
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unlocked = achievement.isUnlocked(user);
    final progress = achievement.progressFor(user);

    return GlassCard(
      padding: const EdgeInsets.all(Gap.sm + 2),
      borderColor: unlocked ? VoixPalette.violet.withValues(alpha: 0.45) : null,
      semanticLabel: '${achievement.title}. ${achievement.description}. '
          '${unlocked ? "Unlocked" : "${(progress * 100).round()} percent"}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.4,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: unlocked ? achievement.gradient : null,
                color: unlocked ? null : c.surfaceHigh,
                shape: BoxShape.circle,
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: achievement.gradient.colors.last
                              .withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                achievement.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          Gap.h8,
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: unlocked ? c.textPrimary : c.textTertiary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          Gap.h8,
          if (unlocked)
            Icon(Icons.check_circle_rounded, size: 17, color: c.success)
          else
            Column(
              children: [
                XpBar(
                  progress: progress,
                  height: 4,
                  showGlow: false,
                  duration: const Duration(milliseconds: 600),
                ),
                const SizedBox(height: 3),
                Text(
                  '${achievement.valueFor(user)}/${achievement.target}',
                  style: context.text.labelSmall?.copyWith(fontSize: 9.5),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.caption,
  });

  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.xl,
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: c.textTertiary),
          Gap.h12,
          Text(title, style: context.text.titleSmall),
          Gap.h4,
          Text(
            caption,
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
