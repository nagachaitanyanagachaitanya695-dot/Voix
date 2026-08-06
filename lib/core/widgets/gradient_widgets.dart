import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// Paints [text] with a gradient shader. Used sparingly — hero numbers,
/// the wordmark, and level titles.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = VoixGradients.brand,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      ),
    );
  }
}

/// An icon filled with a gradient.
class GradientIcon extends StatelessWidget {
  const GradientIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.gradient = VoixGradients.brand,
  });

  final IconData icon;
  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}

/// The rounded-square gradient icon tile used throughout the app for feature
/// rows, quick-access tiles, and settings entries.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.gradient = VoixGradients.brand,
    this.size = 44,
    this.iconSize,
    this.radius,
    this.glow = true,
  });

  final IconData icon;
  final Gradient gradient;
  final double size;
  final double? iconSize;
  final double? radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final tint = gradient.colors.last;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius ?? size * 0.32),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: tint.withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: iconSize ?? size * 0.48, color: Colors.white),
    );
  }
}

/// Soft circular icon badge with a translucent tint instead of a solid
/// gradient — used where a full gradient tile would be too loud.
class SoftIconBadge extends StatelessWidget {
  const SoftIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.46, color: color),
    );
  }
}
