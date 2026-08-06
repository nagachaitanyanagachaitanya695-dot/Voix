import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/staggered.dart';
import '../../data/models/conversation.dart';
import '../../data/models/user_profile.dart';
import '../../providers/conversation_controller.dart';
import '../../providers/user_controller.dart';

/// Presents the roleplay picker and returns the chosen [Scenario], or null if
/// the learner dismissed it.
Future<Scenario?> showScenarioPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Scenario>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ScenarioPickerSheet(),
  );
}

class _ScenarioPickerSheet extends ConsumerWidget {
  const _ScenarioPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scenarios = ref.watch(availableScenariosProvider);
    final user = ref.watch(userControllerProvider);
    final isPro = user?.isPro ?? false;
    final genZ = user?.mode == LearningMode.genZ;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What would you like to practise?',
                    style: context.text.headlineSmall),
                Gap.h4,
                Text(
                  genZ
                      ? 'Casual, slang-heavy conversations.'
                      : 'Pick a situation and start talking.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.xxl),
              itemCount: scenarios.length,
              itemBuilder: (context, i) {
                final s = scenarios[i];
                final locked = s.proOnly && !isPro;
                return FadeSlideIn(
                  index: i,
                  offset: 16,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: GlassCard(
                      onTap: () {
                        if (locked) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This scenario is part of Voix Pro.',
                                ),
                              ),
                            );
                          return;
                        }
                        Navigator.of(context).pop(s);
                      },
                      padding: const EdgeInsets.all(Gap.sm + 2),
                      semanticLabel: '${s.title}. ${s.description}',
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.isDark ? c.surfaceHigh : c.bgAlt,
                              borderRadius: Radii.rSm,
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              s.emoji,
                              style: const TextStyle(fontSize: 22),
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
                                        s.title,
                                        style: context.text.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (s.proOnly) ...[
                                      Gap.w8,
                                      const _ProChip(),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.description,
                                  style: context.text.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            locked
                                ? Icons.lock_rounded
                                : Icons.chevron_right_rounded,
                            size: locked ? 17 : 20,
                            color: locked ? c.gold : c.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: VoixPalette.gold.withValues(alpha: 0.16),
        borderRadius: Radii.rXs,
        border: Border.all(color: VoixPalette.gold.withValues(alpha: 0.4)),
      ),
      child: Text(
        'PRO',
        style: context.text.labelSmall?.copyWith(
          color: VoixPalette.gold,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
