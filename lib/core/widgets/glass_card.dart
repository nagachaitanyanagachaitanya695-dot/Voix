import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../utils/context_ext.dart';
import 'pressable.dart';

/// The base surface for essentially every panel in the app.
///
/// Rather than a real `BackdropFilter` (expensive, and multiplied across a
/// scrolling list it will drop frames), the glass look is faked with a
/// translucent fill, a lit top hairline, and a soft drop shadow. The result is
/// visually equivalent over the aurora backdrop at a fraction of the cost.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.md),
    this.margin,
    this.radius = Radii.lg,
    this.onTap,
    this.borderColor,
    this.fill,
    this.gradient,
    this.elevated = true,
    this.pressScale = 0.98,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  /// Overrides the hairline — used to tint a card toward a feature colour.
  final Color? borderColor;
  final Color? fill;

  /// When set, replaces the flat fill (used by selected states and hero cards).
  final Gradient? gradient;
  final bool elevated;
  final double pressScale;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final br = BorderRadius.circular(radius);

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (fill ?? (c.isDark ? c.surface : c.surface)) : null,
        gradient: gradient,
        borderRadius: br,
        border: Border.all(
          color: borderColor ?? (c.isDark ? c.border : c.border),
          width: 1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: c.isDark ? 24 : 18,
                  offset: const Offset(0, 8),
                  spreadRadius: c.isDark ? -6 : -4,
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    // The lit top edge: a one-pixel highlight that sells the "glass" read.
    if (c.isDark) {
      card = Stack(
        children: [
          card,
          Positioned(
            left: radius * 0.6,
            right: radius * 0.6,
            top: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (margin != null) card = Padding(padding: margin!, child: card);

    if (onTap != null) {
      return Pressable(
        onTap: onTap,
        scale: pressScale,
        borderRadius: br,
        semanticLabel: semanticLabel,
        child: card,
      );
    }
    return card;
  }
}

/// A card whose border and fill are tinted toward [color] — used for selected
/// modes, unlocked achievements, and feature callouts.
class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.child,
    required this.color,
    this.padding = const EdgeInsets.all(Gap.md),
    this.radius = Radii.lg,
    this.onTap,
    this.selected = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.enter,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: c.isDark ? 0.28 : 0.20),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: GlassCard(
        radius: radius,
        padding: padding,
        onTap: onTap,
        elevated: !selected,
        borderColor: selected ? color.withValues(alpha: 0.55) : null,
        fill: selected
            ? Color.alphaBlend(color.withValues(alpha: c.isDark ? 0.12 : 0.07), c.surface)
            : null,
        child: child,
      ),
    );
  }
}
