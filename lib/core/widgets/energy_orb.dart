import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The pulsing energy orb from the splash sequence: a hot core, a rotating
/// corona of radial spikes, and expanding shockwave rings.
///
/// [energy] scales the whole effect (0 = dormant, 1 = full bloom) and is what
/// the splash controller animates; [listening] drives the same orb on the
/// conversation screen, where it reacts to mic amplitude.
class EnergyOrb extends StatefulWidget {
  const EnergyOrb({
    super.key,
    this.size = 220,
    this.energy = 1.0,
    this.amplitude = 0.0,
    this.colors = const [VoixPalette.cyan, VoixPalette.blue, VoixPalette.violet],
    this.showRings = true,
    this.spikes = 64,
  });

  final double size;
  final double energy;

  /// 0→1 live input level. Swells the core and lengthens the spikes.
  final double amplitude;
  final List<Color> colors;
  final bool showRings;
  final int spikes;

  @override
  State<EnergyOrb> createState() => _EnergyOrbState();
}

class _EnergyOrbState extends State<EnergyOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Amplitude is smoothed toward its target so the orb glides rather than
  // jitters when the mic level spikes between frames.
  double _smoothed = 0;

  @override
  void didUpdateWidget(covariant EnergyOrb old) {
    super.didUpdateWidget(old);
    _smoothed += (widget.amplitude - _smoothed) * 0.25;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            _smoothed += (widget.amplitude - _smoothed) * 0.18;
            return CustomPaint(
              painter: _OrbPainter(
                t: _c.value,
                energy: widget.energy.clamp(0.0, 1.0),
                amplitude: _smoothed.clamp(0.0, 1.0),
                colors: widget.colors,
                showRings: widget.showRings,
                spikeCount: widget.spikes,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.t,
    required this.energy,
    required this.amplitude,
    required this.colors,
    required this.showRings,
    required this.spikeCount,
  });

  final double t;
  final double energy;
  final double amplitude;
  final List<Color> colors;
  final bool showRings;
  final int spikeCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (energy <= 0.001) return;

    final centre = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final breathe = 1 + 0.04 * math.sin(t * 2 * math.pi * 2);
    final coreR = maxR * (0.16 + 0.10 * amplitude) * energy * breathe;
    final ringR = maxR * 0.62 * energy;

    // ── Outer halo ─────────────────────────────────────────────────────
    final haloRect = Rect.fromCircle(center: centre, radius: maxR);
    canvas.drawCircle(
      centre,
      maxR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colors.first.withValues(alpha: 0.30 * energy),
            colors[1 % colors.length].withValues(alpha: 0.14 * energy),
            colors.last.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(haloRect),
    );

    // ── Corona spikes ──────────────────────────────────────────────────
    // Two counter-rotating passes read as turbulent plasma rather than a
    // mechanically spinning wheel.
    for (var pass = 0; pass < 2; pass++) {
      final dir = pass == 0 ? 1.0 : -1.0;
      final rot = t * 2 * math.pi * dir * (pass == 0 ? 1.0 : 0.6);
      final count = pass == 0 ? spikeCount : spikeCount ~/ 2;

      for (var i = 0; i < count; i++) {
        final a = (i / count) * 2 * math.pi + rot;
        // Deterministic pseudo-noise keeps spike lengths irregular but stable.
        final noise =
            0.5 + 0.5 * math.sin(i * 12.9898 + t * 6.28 * (pass + 1));
        final len = ringR * (0.12 + 0.34 * noise * (0.55 + 0.75 * amplitude));
        final inner = ringR * (0.94 - pass * 0.06);
        final outer = inner + len;

        canvas.drawLine(
          centre + Offset(math.cos(a), math.sin(a)) * inner,
          centre + Offset(math.cos(a), math.sin(a)) * outer,
          Paint()
            ..color = colors.first
                .withValues(alpha: (0.06 + 0.30 * noise) * energy)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Containment ring ───────────────────────────────────────────────
    canvas.drawCircle(
      centre,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = colors.first.withValues(alpha: 0.85 * energy),
    );
    canvas.drawCircle(
      centre,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = colors.first.withValues(alpha: 0.12 * energy)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Shockwave rings ────────────────────────────────────────────────
    if (showRings) {
      for (var i = 0; i < 3; i++) {
        final p = (t * 1.4 + i / 3) % 1.0;
        final r = ringR + (maxR - ringR) * p;
        canvas.drawCircle(
          centre,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * (1 - p)
            ..color = colors[1 % colors.length]
                .withValues(alpha: 0.35 * (1 - p) * energy),
        );
      }
    }

    // ── Core ───────────────────────────────────────────────────────────
    final coreRect = Rect.fromCircle(center: centre, radius: coreR * 2.6);
    canvas.drawCircle(
      centre,
      coreR * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * energy),
            colors.first.withValues(alpha: 0.65 * energy),
            colors.first.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.32, 1.0],
        ).createShader(coreRect),
    );
    canvas.drawCircle(
      centre,
      coreR,
      Paint()..color = Colors.white.withValues(alpha: 0.92 * energy),
    );

    // Lens flare streaks through the core.
    final flare = Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * energy)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      centre - Offset(coreR * 4.5, 0),
      centre + Offset(coreR * 4.5, 0),
      flare,
    );
    canvas.drawLine(
      centre - Offset(0, coreR * 3.0),
      centre + Offset(0, coreR * 3.0),
      flare,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}
