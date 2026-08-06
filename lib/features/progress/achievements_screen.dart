import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../providers/user_controller.dart';
import 'progress_screen.dart';

/// The full achievement grid, unlocked entries first.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userControllerProvider);
    final achievements = ref.watch(achievementsProvider);
    if (user == null) return const SizedBox.shrink();

    final unlocked = achievements.where((a) => a.isUnlocked(user)).length;

    return Scaffold(
      body: AuroraBackground(
        animate: false,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.sm,
                    Gap.xs,
                    Gap.page,
                    Gap.md,
                  ),
                  child: Row(
                    children: [
                      Pressable(
                        onTap: () => Navigator.of(context).pop(),
                        scale: 0.9,
                        semanticLabel: 'Back',
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.xs),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      Gap.w4,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Achievements',
                              style: context.text.headlineSmall,
                            ),
                            Text(
                              '$unlocked of ${achievements.length} unlocked',
                              style: context.text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const Text('🏆', style: TextStyle(fontSize: 22)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.xxl,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Gap.sm,
                    crossAxisSpacing: Gap.sm,
                    // Tuned so a two-line title plus the progress bar fits
                    // without the card scrolling internally.
                    mainAxisExtent: 168,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i.clamp(0, 8),
                    offset: 16,
                    child: AchievementCard(
                      achievement: achievements[i],
                      user: user,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
