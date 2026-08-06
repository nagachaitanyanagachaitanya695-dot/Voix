import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';
import '../utils/context_ext.dart';
import '../utils/haptics.dart';
import 'pressable.dart';

enum VoixButtonVariant { primary, secondary, ghost, danger }

enum VoixButtonSize { small, medium, large }

/// The app's single button component.
///
/// [VoixButtonVariant.primary] carries the brand gradient and a coloured glow;
/// the others step down in weight so a screen can show a clear primary action
/// without competing emphasis.
class VoixButton extends StatelessWidget {
  const VoixButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = VoixButtonVariant.primary,
    this.size = VoixButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
    this.gradient,
  });

  const VoixButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = VoixButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.expand = true,
    this.loading = false,
  })  : variant = VoixButtonVariant.secondary,
        gradient = null;

  const VoixButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = VoixButtonSize.medium,
    this.icon,
    this.trailingIcon,
    this.expand = false,
    this.loading = false,
  })  : variant = VoixButtonVariant.ghost,
        gradient = null;

  final String label;
  final VoidCallback? onPressed;
  final VoixButtonVariant variant;
  final VoixButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expand;
  final bool loading;
  final Gradient? gradient;

  bool get _enabled => onPressed != null && !loading;

  double get _height => switch (size) {
        VoixButtonSize.small => 40,
        VoixButtonSize.medium => 48,
        VoixButtonSize.large => 56,
      };

  double get _fontSize => switch (size) {
        VoixButtonSize.small => 13,
        VoixButtonSize.medium => 14.5,
        VoixButtonSize.large => 16,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isPrimary = variant == VoixButtonVariant.primary;
    final isDanger = variant == VoixButtonVariant.danger;

    final effectiveGradient = gradient ??
        (isDanger
            ? const LinearGradient(colors: [Color(0xFFFB7185), Color(0xFFE11D48)])
            : VoixGradients.brandSoft);

    final fg = switch (variant) {
      VoixButtonVariant.primary || VoixButtonVariant.danger => Colors.white,
      VoixButtonVariant.secondary => c.textPrimary,
      VoixButtonVariant.ghost => c.textSecondary,
    };

    final glowColor = effectiveGradient.colors.last;

    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: _fontSize,
            height: _fontSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          ),
          Gap.w12,
        ] else if (icon != null) ...[
          Icon(icon, size: _fontSize + 3, color: fg),
          Gap.w8,
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (trailingIcon != null && !loading) ...[
          Gap.w8,
          Icon(trailingIcon, size: _fontSize + 3, color: fg),
        ],
      ],
    );

    final decoration = switch (variant) {
      VoixButtonVariant.primary || VoixButtonVariant.danger => BoxDecoration(
          gradient: effectiveGradient,
          borderRadius: Radii.rPill,
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: c.isDark ? 0.42 : 0.30),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
      VoixButtonVariant.secondary => BoxDecoration(
          color: c.isDark ? c.surfaceHigh : c.surface,
          borderRadius: Radii.rPill,
          border: Border.all(color: c.borderStrong),
        ),
      VoixButtonVariant.ghost => const BoxDecoration(
          borderRadius: Radii.rPill,
        ),
    };

    return Pressable(
      enabled: _enabled,
      scale: 0.97,
      haptic: false,
      onTap: _enabled
          ? () {
              isPrimary ? Haptic.light() : Haptic.tap();
              onPressed!.call();
            }
          : null,
      borderRadius: Radii.rPill,
      semanticLabel: label,
      child: Container(
        height: _height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: expand ? Gap.lg : (size == VoixButtonSize.small ? Gap.md : Gap.xl),
        ),
        decoration: decoration,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
