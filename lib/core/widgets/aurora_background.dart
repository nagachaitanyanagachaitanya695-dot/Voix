import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/context_ext.dart';

/// The ambient backdrop shared by every screen.
///
/// Two large, slowly drifting colour blooms sit behind the page content. They
/// are painted once into a single layer (no blur filters, no stacked opacity
/// layers) which keeps the effect essentially free on the raster thread — the
/// alternative, a stack of `BackdropFilter`s, is what usually costs a dark
/// gradient UI its frame budget on mid-range Android.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.intensity = 1.0,
    this.colors,
  });

  final Widget child;

  /// Set false on dense/scrolling screens where the drift is not visible
  /// anyway — saves a repaint per frame.
  final bool animate;

  /// Scales bloom opacity. Onboarding and splash push this above 1.
  final double intensity;

  /// Override the two bloom hues (defaults to blue + violet).
  final List<Color>? colors;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AuroraBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final blooms = widget.colors ?? [VoixPalette.blue, VoixPalette.violet];

    return DecoratedBox(
      decoration: BoxDecoration(color: c.bg),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(
                  painter: _AuroraPainter(
                    t: _c.value,
                    colors: blooms,
                    isDark: c.isDark,
                    intensity: widget.intensity,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.isDark,
    required this.intensity,
  });

  final double t;
  final List<Color> colors;
  final bool isDark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    // Blooms are oversized and anchored off-screen so only their soft falloff
    // enters the frame — that is what reads as a diffuse glow without a blur.
    final r = size.width * 1.15;
    final baseAlpha = (isDark ? 0.20 : 0.13) * intensity;

    void bloom(Offset centre, Color color, double alpha) {
      final rect = Rect.fromCircle(center: centre, radius: r);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * 0.45),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.42, 1.0],
          ).createShader(rect),
      );
    }

    final a = t * 2 * math.pi;

    bloom(
      Offset(
        size.width * (0.12 + 0.06 * math.sin(a)),
        size.height * (0.08 + 0.04 * math.cos(a * 0.8)),
      ),
      colors.first,
      baseAlpha,
    );

    bloom(
      Offset(
        size.width * (0.92 + 0.05 * math.cos(a * 0.7)),
        size.height * (0.34 + 0.05 * math.sin(a * 1.1)),
      ),
      colors.last,
      baseAlpha * 0.85,
    );

    // A third, dimmer bloom low on the page keeps long scrolls from going flat.
    bloom(
      Offset(
        size.width * (0.5 + 0.1 * math.sin(a * 0.5)),
        size.height * 1.02,
      ),
      colors.length > 2 ? colors[1] : VoixPalette.cyan,
      baseAlpha * 0.55,
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t ||
      old.intensity != intensity ||
      old.isDark != isDark ||
      old.colors != colors;
}
