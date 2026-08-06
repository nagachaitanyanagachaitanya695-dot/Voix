import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_card.dart';

/// A selectable row used throughout onboarding: leading glyph, label,
/// optional description, and an animated check on the right.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.emoji,
    this.icon,
    this.trailing,
    this.accent,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = accent ?? c.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: AccentCard(
        color: tint,
        selected: selected,
        radius: Radii.md,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm + 2,
        ),
        child: Row(
          children: [
            if (emoji != null)
              SizedBox(
                width: 34,
                child: Text(emoji!, style: const TextStyle(fontSize: 20)),
              )
            else if (icon != null)
              SizedBox(
                width: 34,
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? tint : c.textSecondary,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.text.titleMedium?.copyWith(
                      color: c.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: context.text.bodySmall
                          ?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            Gap.w8,
            _Check(selected: selected, tint: tint, border: c.borderStrong),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.selected,
    required this.tint,
    required this.border,
  });

  final bool selected;
  final Color tint;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.pop,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? tint : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? tint : border,
          width: 1.6,
        ),
      ),
      child: AnimatedScale(
        duration: Motion.base,
        curve: Motion.pop,
        scale: selected ? 1 : 0,
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      ),
    );
  }
}

/// Larger square card for two-up choices (tutor voice, learning mode).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.emoji,
    this.icon,
    this.accent,
    this.height = 150,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;
  final IconData? icon;
  final Color? accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = accent ?? c.primary;

    return AccentCard(
      color: tint,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.md),
      // A minimum rather than a fixed height: a two-line subtitle or a large
      // accessibility text scale must push the card taller, not overflow it.
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedScale(
                duration: Motion.base,
                curve: Motion.pop,
                scale: selected ? 1 : 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (emoji != null)
                  Text(emoji!, style: const TextStyle(fontSize: 42))
                else if (icon != null)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: selected ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 26,
                      color: selected ? tint : c.textSecondary,
                    ),
                  ),
                Gap.h12,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  Gap.h4,
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
