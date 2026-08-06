import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/staggered.dart';
import '../../../data/models/conversation.dart';

/// One turn of the conversation.
///
/// Tutor turns sit left on a neutral surface; learner turns sit right on the
/// brand gradient. When a learner turn carries corrections, a subtle chip
/// appears beneath it that expands in place — the fix is available immediately
/// but never interrupts the flow of the conversation.
class ChatBubble extends StatefulWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUser = widget.message.speaker == Speaker.user;
    final corrections = widget.message.corrections;

    return FadeSlideIn(
      offset: 12,
      duration: Motion.slow,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) ...[
                  const _TutorAvatar(),
                  Gap.w8,
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: context.screenW * 0.74,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md,
                      vertical: Gap.sm,
                    ),
                    decoration: BoxDecoration(
                      gradient: isUser ? VoixGradients.brandSoft : null,
                      color: isUser ? null : (c.isDark ? c.surface : c.surface),
                      border: isUser ? null : Border.all(color: c.border),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(Radii.md),
                        topRight: const Radius.circular(Radii.md),
                        bottomLeft: Radius.circular(isUser ? Radii.md : 4),
                        bottomRight: Radius.circular(isUser ? 4 : Radii.md),
                      ),
                      boxShadow: isUser
                          ? [
                              BoxShadow(
                                color: VoixPalette.blue.withValues(alpha: 0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                                spreadRadius: -6,
                              ),
                            ]
                          : null,
                    ),
                    child: SelectableText(
                      widget.message.text,
                      style: context.text.bodyLarge?.copyWith(
                        color: isUser ? Colors.white : c.textPrimary,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Correction affordance ────────────────────────────────
            if (isUser && corrections.isNotEmpty) ...[
              Gap.h4,
              Pressable(
                onTap: () => setState(() => _expanded = !_expanded),
                scale: 0.97,
                semanticLabel: _expanded
                    ? 'Hide correction'
                    : '${corrections.length} correction available',
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.enter,
                  constraints: BoxConstraints(maxWidth: context.screenW * 0.78),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: Gap.xs,
                  ),
                  decoration: BoxDecoration(
                    color: c.warning.withValues(alpha: 0.10),
                    borderRadius: Radii.rSm,
                    border: Border.all(
                      color: c.warning.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 14,
                            color: c.warning,
                          ),
                          Gap.w4,
                          Flexible(
                            child: Text(
                              _expanded
                                  ? 'Suggested fix'
                                  : '${corrections.length} '
                                      '${corrections.length == 1 ? "tip" : "tips"}'
                                      ' — tap to see',
                              style: context.text.labelSmall?.copyWith(
                                color: c.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Gap.w4,
                          Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 15,
                            color: c.warning,
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        duration: Motion.base,
                        sizeCurve: Motion.enter,
                        crossFadeState: _expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox(width: double.infinity),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                corrections.first.corrected,
                                style: context.text.bodySmall?.copyWith(
                                  color: c.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Gap.h4,
                              for (final correction in corrections)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '• ${correction.explanation}',
                                    style: context.text.labelSmall?.copyWith(
                                      color: c.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TutorAvatar extends StatelessWidget {
  const _TutorAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        gradient: VoixGradients.brand,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
    );
  }
}

/// Three-dot indicator shown while the tutor composes a reply.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          const _TutorAvatar(),
          Gap.w8,
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm + 2,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Radii.md),
                topRight: Radius.circular(Radii.md),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(Radii.md),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // Each dot lags the previous by a third of the cycle.
                  final phase = (_c.value - i * 0.18) % 1.0;
                  final lift = phase < 0.5
                      ? Curves.easeOut.transform(phase * 2)
                      : Curves.easeIn.transform((1 - phase) * 2);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Transform.translate(
                      offset: Offset(0, -3.5 * lift),
                      child: Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: c.textTertiary.withValues(
                            alpha: 0.45 + 0.55 * lift,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
