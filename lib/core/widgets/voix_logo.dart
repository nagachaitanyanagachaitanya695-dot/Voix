import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../utils/context_ext.dart';

/// The VOIX mark: a speech bubble holding a microphone, with sound waves
/// radiating from its right edge — conversation and voice in one glyph.
///
/// Drawn entirely with paths (no raster asset) so it stays crisp at every
/// density, animates its own stroke on the splash, and recolours per theme.
class VoixLogo extends StatelessWidget {
  const VoixLogo({
    super.key,
    this.size = 64,
    this.gradient = VoixGradients.brand,
    this.filled = true,
    this.cutoutColor,
    this.strokeScale = 1.0,
    this.drawProgress = 1.0,
  });

  final double size;
  final Gradient gradient;

  /// Filled: solid gradient bubble with a knocked-out mic (the app-icon look).
  /// Outline: every element stroked — used during the splash draw-on.
  final bool filled;

  /// Colour the mic is knocked out to in filled mode. Defaults to page bg.
  final Color? cutoutColor;
  final double strokeScale;

  /// 0→1 stroke reveal, driven by the splash controller.
  final double drawProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _VoixLogoPainter(
          gradient: gradient,
          filled: filled,
          cutout: cutoutColor ?? context.colors.bg,
          strokeScale: strokeScale,
          progress: drawProgress.clamp(0.0, 1.0),
        ),
      ),
    );
  }
}

class _VoixLogoPainter extends CustomPainter {
  _VoixLogoPainter({
    required this.gradient,
    required this.filled,
    required this.cutout,
    required this.strokeScale,
    required this.progress,
  });

  final Gradient gradient;
  final bool filled;
  final Color cutout;
  final double strokeScale;
  final double progress;

  // Geometry is authored in a 100×100 box and scaled to the widget size.
  static const _centre = Offset(46, 40);
  static const _bubbleR = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100.0;
    canvas.save();
    canvas.scale(s);

    final rect = const Rect.fromLTWH(0, 0, 100, 100);
    final shader = gradient.createShader(rect);

    final fillPaint = Paint()..shader = shader;
    final strokePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.5 * strokeScale;

    // ── Bubble (circle unioned with a curved tail) ──────────────────────
    final bubble = Path.combine(
      PathOperation.union,
      Path()..addOval(Rect.fromCircle(center: _centre, radius: _bubbleR)),
      Path()
        ..moveTo(26, 62)
        ..quadraticBezierTo(21, 80, 11, 86)
        ..quadraticBezierTo(28, 83, 40, 70)
        ..close(),
    );

    if (filled) {
      canvas.drawPath(bubble, fillPaint);
    } else {
      canvas.drawPath(_trim(bubble, progress), strokePaint);
    }

    // ── Microphone ─────────────────────────────────────────────────────
    final micPaint = filled
        ? (Paint()..color = cutout)
        : (Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 4.0 * strokeScale);

    final capsule = RRect.fromRectAndRadius(
      const Rect.fromLTRB(39.5, 23, 52.5, 46),
      const Radius.circular(6.5),
    );

    if (filled) {
      canvas.drawRRect(capsule, micPaint);
    } else {
      canvas.drawPath(_trim(Path()..addRRect(capsule), progress), micPaint);
    }

    // Cradle: the open U that the capsule sits in.
    final cradleStroke = Paint()
      ..color = filled ? cutout : const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.4 * strokeScale;
    if (!filled) cradleStroke.shader = shader;

    final cradle = Path()
      ..addArc(
        Rect.fromCircle(center: _centre, radius: 12.6),
        0, // 0 rad = +x axis
        math.pi, // sweep through the bottom half
      );
    canvas.drawPath(filled ? cradle : _trim(cradle, progress), cradleStroke);

    // Stem dropping from the cradle.
    final stem = Path()
      ..moveTo(46, 52.6)
      ..lineTo(46, 59.5);
    canvas.drawPath(filled ? stem : _trim(stem, progress), cradleStroke);

    // ── Sound waves ────────────────────────────────────────────────────
    // Revealed last, so on the splash the mark draws itself and *then*
    // "speaks".
    final waveT = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
    if (waveT > 0) {
      for (var i = 0; i < 2; i++) {
        final r = 36.0 + i * 9.0;
        final sweep = (30 - i * 3) * math.pi / 180;
        final wave = Path()
          ..addArc(
            Rect.fromCircle(center: _centre, radius: r),
            -sweep,
            sweep * 2,
          );
        canvas.drawPath(
          _trim(wave, waveT),
          Paint()
            ..shader = shader
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = (4.2 - i * 0.9) * strokeScale,
        );
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
      old.cutout != cutout ||
      old.strokeScale != strokeScale;
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
        VoixLogo(size: markSize, gradient: gradient),
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
