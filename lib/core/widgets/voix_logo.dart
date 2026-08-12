import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// The VOIX mark: a speech-bubble ring holding a microphone, with sound waves
/// radiating from its right edge — conversation and voice in one glyph.
///
/// Drawn entirely with paths rather than shipped as an image, so it stays
/// crisp at every density, recolours per theme, and can draw its own stroke on
/// the splash. The geometry follows the supplied brand icon: a hollow bubble
/// with a solid mic inside it and three arcs, not a solid bubble with the mic
/// knocked out.
class VoixLogo extends StatelessWidget {
  const VoixLogo({
    super.key,
    this.size = 64,
    this.gradient = VoixGradients.brand,
    this.filled = true,
    this.strokeScale = 1.0,
    this.drawProgress = 1.0,
    this.glow = true,
  });

  final double size;
  final Gradient gradient;

  /// Filled: the mic is a solid shape — the app-icon look.
  /// Outline: every element is stroked, used during the splash draw-on.
  final bool filled;

  final double strokeScale;

  /// 0→1 stroke reveal, driven by the splash controller.
  final double drawProgress;

  /// The neon bloom behind the mark. Costs a blurred repaint, so it is off for
  /// the small instances that appear inside lists.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VoixLogoPainter(
          gradient: gradient,
          filled: filled,
          strokeScale: strokeScale,
          progress: drawProgress.clamp(0.0, 1.0),
          glow: glow,
        ),
      ),
    );
  }
}

class _VoixLogoPainter extends CustomPainter {
  _VoixLogoPainter({
    required this.gradient,
    required this.filled,
    required this.strokeScale,
    required this.progress,
    required this.glow,
  });

  final Gradient gradient;
  final bool filled;
  final double strokeScale;
  final double progress;
  final bool glow;

  // Geometry is authored in a 100×100 box and scaled to the widget size.
  static const _centre = Offset(42, 44);
  static const _bubbleR = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100.0;
    canvas.save();
    canvas.scale(s);

    const rect = Rect.fromLTWH(0, 0, 100, 100);
    final shader = gradient.createShader(rect);

    Paint stroke(double width) => Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * strokeScale;

    // ── Bubble: a ring with a tail, not a filled blob ──────────────────
    final bubble = Path()
      ..addOval(Rect.fromCircle(center: _centre, radius: _bubbleR));
    // A short pointed tail off the lower-left. Both ends are anchored on the
    // circle itself — ending short of it made the tail look like it cut
    // across the microphone.
    final tail = Path()
      ..moveTo(23, 64)
      ..quadraticBezierTo(19, 76, 13, 83)
      ..quadraticBezierTo(26, 78, 34, 71);

    // ── Microphone ─────────────────────────────────────────────────────
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(35, 24, 49, 49),
          const Radius.circular(7),
        ),
      );
    // The grille lines across the capsule, as on the brand icon.
    final grille = Path();
    for (var i = 0; i < 3; i++) {
      final y = 32.0 + i * 5.0;
      grille
        ..moveTo(37, y)
        ..lineTo(47, y);
    }
    // The open U the capsule sits in.
    final cradle = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(42, 45), radius: 12),
        0, // +x axis
        math.pi, // sweep through the bottom half
      );
    final stem = Path()
      ..moveTo(42, 57)
      ..lineTo(42, 63);
    final base = Path()
      ..moveTo(34, 63)
      ..lineTo(50, 63);

    // ── Sound waves: three arcs, as on the brand icon ──────────────────
    // Revealed last, so on the splash the mark draws itself and *then*
    // "speaks".
    final waveT = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
    final waves = <({Path path, double width})>[
      for (var i = 0; i < 3; i++)
        (
          path: Path()
            ..addArc(
              Rect.fromCircle(center: _centre, radius: 40.0 + i * 11.0),
              -(34 - i * 4) * math.pi / 180,
              (34 - i * 4) * 2 * math.pi / 180,
            ),
          width: 4.6 - i * 0.7,
        ),
    ];

    // ── Paint ──────────────────────────────────────────────────────────
    // The bloom is the same geometry drawn first through a blur, which is what
    // gives the icon its neon look without needing a second asset.
    if (glow) {
      final bloom = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0 * strokeScale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas
        ..drawPath(_trim(bubble, progress), bloom)
        ..drawPath(_trim(tail, progress), bloom);
      for (final w in waves) {
        if (waveT > 0) canvas.drawPath(_trim(w.path, waveT), bloom);
      }
    }

    canvas
      ..drawPath(_trim(bubble, progress), stroke(5.0))
      ..drawPath(_trim(tail, progress), stroke(5.0));

    // The mic is solid in the icon and stroked while the splash draws itself.
    if (filled) {
      canvas
        ..drawPath(capsule, Paint()..shader = shader)
        // Cut into the solid capsule with a translucent dark stroke rather
        // than the page colour, so the grille reads correctly on any ground.
        ..drawPath(
          grille,
          Paint()
            ..color = const Color(0x33000B1F)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.6 * strokeScale,
        );
    } else {
      canvas.drawPath(_trim(capsule, progress), stroke(3.6));
    }
    canvas
      ..drawPath(filled ? cradle : _trim(cradle, progress), stroke(3.4))
      ..drawPath(filled ? stem : _trim(stem, progress), stroke(3.4))
      ..drawPath(filled ? base : _trim(base, progress), stroke(3.4));

    if (waveT > 0) {
      for (final w in waves) {
        canvas.drawPath(_trim(w.path, waveT), stroke(w.width));
      }
    }

    canvas.restore();
  }

  /// Returns the leading [t] fraction of [path]'s length — the mechanism
  /// behind the splash's self-drawing stroke.
  Path _trim(Path path, double t) {
    if (t >= 1.0) return path;
    if (t <= 0.0) return Path();
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _VoixLogoPainter old) =>
      old.progress != progress ||
      old.filled != filled ||
      old.strokeScale != strokeScale ||
      old.glow != glow;
}

/// The horizontal lockup — mark plus "Voix" wordmark.
class VoixWordmark extends StatelessWidget {
  const VoixWordmark({
    super.key,
    this.markSize = 40,
    this.fontSize = 30,
    this.gradient = VoixGradients.brand,
    this.color,
  });

  final double markSize;
  final double fontSize;
  final Gradient gradient;

  /// When set, the wordmark is drawn flat in this colour instead of gradient.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: color ?? Colors.white,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VoixLogo(size: markSize, gradient: gradient, glow: false),
        SizedBox(width: markSize * 0.22),
        if (color != null)
          Text('Voix', style: style)
        else
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) =>
                gradient.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
            child: Text('Voix', style: style),
          ),
      ],
    );
  }
}
