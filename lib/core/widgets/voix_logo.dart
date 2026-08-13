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

  // Geometry is authored in a 100×100 box and scaled to the widget size, with
  // every coordinate measured off the supplied brand tile. The bubble is
  // deliberately left of centre: the wave fan needs the right third of the box.
  static const _centre = Offset(38, 45);
  static const _bubbleR = 24.0;

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

    // ── Bubble: one continuous outline — ring plus tail ────────────────
    // The ring is broken between 112° and 143° and the stroke runs out to the
    // tail's point and back instead of closing across. Drawing the tail as a
    // second path over a complete circle leaves a sliver between the two,
    // which the glow then floods into a solid wedge; this way there is nothing
    // to trap, and the mark reads as the single unbroken line it is on the
    // brand tile.
    const tailStart = 143.0; // lower-left, where the outline leaves the ring
    const tailEnd = 112.0; //   bottom-left, where it rejoins
    // The long way round: everything except the span the tail occupies. Skia
    // normalises a sweep past a full turn, so this has to be the 329° arc,
    // not 143 − 112 + 360.
    const ringSweep = 360.0 - (tailStart - tailEnd);
    final bubble = Path()
      ..arcTo(
        Rect.fromCircle(center: _centre, radius: _bubbleR),
        tailStart * math.pi / 180,
        ringSweep * math.pi / 180,
        true,
      )
      // The arc ends at 112°, (29.01, 67.25). Out to the point, then back up
      // to where the ring was left at 143°, (18.83, 59.44).
      ..quadraticBezierTo(23, 73.5, 12, 79.5)
      ..quadraticBezierTo(15, 69, 18.83, 59.44)
      ..close();

    // ── Microphone ─────────────────────────────────────────────────────
    // A stadium, not a rounded rectangle: on the brand tile the capsule's top
    // and bottom are full semicircles.
    const capsuleRect = Rect.fromLTRB(28.5, 29.5, 47.5, 60);
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          capsuleRect,
          const Radius.circular(9.5), // half the capsule's 19-unit width
        ),
      );
    // The grille reads as short ticks against each edge of the capsule with a
    // clear gap down the middle, not as lines ruled across it.
    final grille = Path();
    for (var i = 0; i < 3; i++) {
      final y = 41.5 + i * 4.5;
      grille
        ..moveTo(30.0, y)
        ..lineTo(34.2, y)
        ..moveTo(42.0, y)
        ..lineTo(46.2, y);
    }
    // The open U the capsule sits in.
    final cradle = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(38.5, 48.75), radius: 13.75),
        0, // +x axis
        math.pi, // sweep through the bottom half
      );
    final stem = Path()
      ..moveTo(38.5, 62.5)
      ..lineTo(38.5, 68);
    // A short foot, roughly half the capsule's width.
    final base = Path()
      ..moveTo(34.5, 68)
      ..lineTo(42.5, 68);

    // ── Sound waves: three arcs, as on the brand icon ──────────────────
    // Each arc is concentric with the bubble and fans *wider* than the one
    // inside it — the near tick is short, the far arc sweeps almost a
    // quadrant. Revealed last, so on the splash the mark draws itself and
    // *then* "speaks".
    const waveArcs = <({double radius, double halfAngle, double width})>[
      (radius: 32, halfAngle: 17, width: 3.6),
      (radius: 41, halfAngle: 33, width: 4.0),
      (radius: 50, halfAngle: 40, width: 4.4),
    ];
    final waveT = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
    final waves = <({Path path, double width})>[
      for (final arc in waveArcs)
        (
          path: Path()
            ..addArc(
              Rect.fromCircle(center: _centre, radius: arc.radius),
              -arc.halfAngle * math.pi / 180,
              arc.halfAngle * 2 * math.pi / 180,
            ),
          width: arc.width,
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
        // Kept narrower than the stroke it sits under: a wide bloom closes the
        // gap inside the tail and turns the spike into a filled triangle.
        ..strokeWidth = 3.5 * strokeScale
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(_trim(bubble, progress), bloom);
      for (final w in waves) {
        if (waveT > 0) canvas.drawPath(_trim(w.path, waveT), bloom);
      }
    }

    canvas.drawPath(_trim(bubble, progress), stroke(4.6));

    // The mic is solid in the icon and stroked while the splash draws itself.
    if (filled) {
      canvas
        ..drawPath(capsule, Paint()..shader = shader)
        // Cut into the solid capsule with a translucent dark stroke rather
        // than the page colour, so the grille reads correctly on any ground.
        ..drawPath(
          grille,
          Paint()
            ..color = const Color(0x4D000B1F)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.8 * strokeScale,
        );
    } else {
      canvas.drawPath(_trim(capsule, progress), stroke(3.4));
    }
    canvas
      ..drawPath(filled ? cradle : _trim(cradle, progress), stroke(3.6))
      ..drawPath(filled ? stem : _trim(stem, progress), stroke(3.6))
      ..drawPath(filled ? base : _trim(base, progress), stroke(3.6));

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
