import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// Live audio bar visualiser used while the mic is open and while the tutor
/// speaks back.
///
/// Bars are driven by a smoothed [amplitude] plus a per-bar phase offset, so
/// silence still shows a gentle idle shimmer instead of a dead flat line.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    this.amplitude = 0.0,
    this.bars = 28,
    this.height = 56,
    this.gradient = VoixGradients.brand,
    this.active = true,
    this.barWidth = 3.5,
  });

  final double amplitude;
  final int bars;
  final double height;
  final Gradient gradient;
  final bool active;
  final double barWidth;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  double _smoothed = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final target = widget.active ? widget.amplitude : 0.0;
            _smoothed += (target - _smoothed) * 0.2;
            return CustomPaint(
              painter: _WavePainter(
                t: _c.value,
                amplitude: _smoothed.clamp(0.0, 1.0),
                bars: widget.bars,
                gradient: widget.gradient,
                barWidth: widget.barWidth,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.t,
    required this.amplitude,
    required this.bars,
    required this.gradient,
    required this.barWidth,
  });

  final double t;
  final double amplitude;
  final int bars;
  final Gradient gradient;
  final double barWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final gap = size.width / bars;
    final midY = size.height / 2;

    for (var i = 0; i < bars; i++) {
      final x = gap * (i + 0.5);
      // Envelope tapers the ends so the waveform reads as a lens shape.
      final envelope = math.sin((i / (bars - 1)) * math.pi);
      final phase = t * 2 * math.pi + i * 0.55;
      final wobble = 0.5 + 0.5 * math.sin(phase);
      final idle = 0.06 + 0.05 * wobble;
      final h = size.height *
          envelope *
          (idle + amplitude * 0.85 * wobble) *
          0.95;
      final half = math.max(barWidth / 2, h / 2);

      canvas.drawLine(
        Offset(x, midY - half),
        Offset(x, midY + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}
