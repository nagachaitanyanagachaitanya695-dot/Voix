import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../data/content/lesson_catalog.dart';
import '../../data/models/lesson.dart';
import '../../providers/user_controller.dart';
import 'lesson_player_screen.dart';
import 'slang_reference_screen.dart';

/// The lesson library, filterable by category.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  LessonCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userControllerProvider);
    if (user == null) return const SizedBox.shrink();

    final lessons = _filter == null
        ? LessonCatalog.all
        : LessonCatalog.byCategory(_filter!);

    final completed = user.completedLessonIds;
    final done =
        LessonCatalog.all.where((l) => completed.contains(l.id)).length;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: FadeSlideIn(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Learn', style: context.text.displaySmall),
                    Gap.h4,
                    Text(
                      '$done of ${LessonCatalog.all.length} lessons completed',
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Gen-Z reference shortcut ──────────────────────────────
          SliverToBoxAdapter(
            child: FadeSlideIn(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  0,
                ),
                child: AccentCard(
                  color: VoixPalette.magenta,
                  padding: const EdgeInsets.all(Gap.sm + 2),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SlangReferenceScreen(),
                    ),
                  ),
                  child: Row(
                    children: [
                      const IconTile(
                        icon: Icons.emoji_emotions_rounded,
                        size: 40,
                        gradient: LinearGradient(
                          colors: [VoixPalette.violet, VoixPalette.magenta],
                        ),
                      ),
                      Gap.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gen-Z Dictionary',
                              style: context.text.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Slang, shortforms & emoji meanings',
                              style: context.text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Category filter ───────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeSlideIn(
              index: 2,
              // Vertical spacing lives outside the list: on a horizontal
              // ListView, top padding eats the cross-axis extent and squeezes
              // the chips instead of moving them down.
              child: Padding(
                padding: const EdgeInsets.only(top: Gap.md),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final category in LessonCategory.values)
                        _FilterChip(
                          key: ValueKey('filter_${category.name}'),
                          label: category.label,
                          icon: category.icon,
                          selected: _filter == category,
                          onTap: () => setState(() => _filter = category),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 110),
            sliver: lessons.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Gap.xxxl),
                      child: Center(
                        child: Text(
                          'No lessons here yet.',
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ),
                  )
                : SliverList.separated(
                    itemCount: lessons.length,
                    separatorBuilder: (_, __) => Gap.h12,
                    itemBuilder: (context, i) => FadeSlideIn(
                      index: i.clamp(0, 8),
                      child: _LessonCard(
                        lesson: lessons[i],
                        completed: completed.contains(lessons[i].id),
                        locked: lessons[i].proOnly && !user.isPro,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(right: Gap.xs),
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2),
          decoration: BoxDecoration(
            color: selected ? c.primary : (c.isDark ? c.surface : c.surface),
            borderRadius: Radii.rPill,
            border: Border.all(color: selected ? c.primary : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : c.textTertiary,
                ),
                Gap.w4,
              ],
              Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: selected ? Colors.white : c.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.completed,
    required this.locked,
  });

  final Lesson lesson;
  final bool completed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return GlassCard(
      padding: const EdgeInsets.all(Gap.sm + 2),
      semanticLabel: '${lesson.title}. ${lesson.subtitle}. '
          '${lesson.estimatedMinutes} minutes. '
          '${completed ? "Completed" : "Not started"}',
      onTap: () {
        if (locked) {
          Haptic.error();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('This lesson is part of Voix Pro.')),
            );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LessonPlayerScreen(lesson: lesson)),
        );
      },
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: lesson.category.gradient,
              borderRadius: Radii.rSm,
            ),
            child: Text(lesson.emoji, style: const TextStyle(fontSize: 22)),
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
                        lesson.title,
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (completed) ...[
                      Gap.w4,
                      Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: c.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  lesson.subtitle,
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap.h8,
                Row(
                  children: [
                    _MetaChip(
                      label: lesson.category.label,
                      color: c.textTertiary,
                    ),
                    Gap.w8,
                    _MetaChip(
                      label: '${lesson.estimatedMinutes} min',
                      color: c.textTertiary,
                    ),
                    Gap.w8,
                    _MetaChip(
                      label: '+${lesson.xpReward} XP',
                      color: c.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            locked ? Icons.lock_rounded : Icons.chevron_right_rounded,
            size: locked ? 17 : 20,
            color: locked ? c.gold : c.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelSmall?.copyWith(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
