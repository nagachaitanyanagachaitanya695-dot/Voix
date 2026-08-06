import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';
import '../utils/context_ext.dart';

/// Slim animated progress track used for XP-to-next-level and daily goal.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.gradient = VoixGradients.brandSoft,
    this.trackColor,
    this.duration = const Duration(milliseconds: 1000),
    this.showGlow = true,
  });

  /// 0→1.
  final double progress;
  final double height;
  final Gradient gradient;
  final Color? trackColor;
  final Duration duration;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: trackColor ?? (c.isDark ? c.surfaceHigh : c.bgAlt),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v == 0 ? 0.001 : v,
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                  boxShadow: showGlow
                      ? [
                          BoxShadow(
                            color: gradient.colors.last.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Level badge — the hexagon carrying the user's current level number.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
    this.size = 56,
    this.icon = Icons.star_rounded,
  });

  final int level;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexPainter(),
        child: Center(
          child: Icon(icon, size: size * 0.42, color: Colors.white),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _hexPath(size);

    canvas.drawPath(
      path,
      Paint()
        ..shader = VoixGradients.brand.createShader(rect)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  Path _hexPath(Size size) {
    // Flat-top hexagon inscribed in the box, with softened corners implied by
    // the stroke join.
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.94, h * 0.26)
      ..lineTo(w * 0.94, h * 0.74)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.06, h * 0.74)
      ..lineTo(w * 0.06, h * 0.26)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// The flame + day-count pill shown in the app bar.
class StreakPill extends StatelessWidget {
  const StreakPill({
    super.key,
    required this.days,
    this.showLabel = false,
    this.onTap,
  });

  final int days;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$days day learning streak',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? Gap.sm : Gap.xs + 2,
          vertical: showLabel ? Gap.xs : 6,
        ),
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceHigh : c.surface,
          borderRadius: Radii.rPill,
          border: Border.all(color: c.streak.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: c.streak.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 15)),
            Gap.w4,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$days',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
                if (showLabel)
                  Text(
                    'Day Streak',
                    style: context.text.labelSmall?.copyWith(fontSize: 9.5),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
