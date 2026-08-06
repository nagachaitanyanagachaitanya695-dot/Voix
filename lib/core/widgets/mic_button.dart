import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';
import '../utils/haptics.dart';

/// The app's signature control: a large glowing microphone with pulse rings
/// that expand while recording.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.onTap,
    this.recording = false,
    this.size = 96,
    this.amplitude = 0.0,
    this.enabled = true,
    this.icon,
  });

  final VoidCallback onTap;
  final bool recording;
  final double size;
  final double amplitude;
  final bool enabled;
  final IconData? icon;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 130),
    lowerBound: 0,
    upperBound: 0.06,
  );

  @override
  void initState() {
    super.initState();
    if (widget.recording) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant MicButton old) {
    super.didUpdateWidget(old);
    if (widget.recording && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.recording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = widget.recording
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
          )
        : VoixGradients.brandSoft;
    final glow = gradient.colors.last;
    final ringSpace = widget.size * 0.55;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _press.forward() : null,
      onTapUp: widget.enabled ? (_) => _press.reverse() : null,
      onTapCancel: widget.enabled ? () => _press.reverse() : null,
      onTap: widget.enabled
          ? () {
              Haptic.medium();
              widget.onTap();
            }
          : null,
      child: SizedBox(
        width: widget.size + ringSpace,
        height: widget.size + ringSpace,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Expanding pulse rings while recording.
            if (widget.recording)
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => CustomPaint(
                    size: Size.square(widget.size + ringSpace),
                    painter: _PulsePainter(
                      t: _pulse.value,
                      color: glow,
                      base: widget.size / 2,
                      amplitude: widget.amplitude,
                    ),
                  ),
                ),
              ),

            AnimatedBuilder(
              animation: _press,
              builder: (_, child) => Transform.scale(
                scale: 1 - _press.value,
                child: child,
              ),
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.enter,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glow.withValues(alpha: widget.recording ? 0.60 : 0.45),
                      blurRadius: widget.recording ? 40 : 28,
                      spreadRadius: widget.recording ? -2 : -6,
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon ??
                      (widget.recording ? Icons.stop_rounded : Icons.mic_rounded),
                  color: Colors.white,
                  size: widget.size * 0.42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.t,
    required this.color,
    required this.base,
    required this.amplitude,
  });

  final double t;
  final Color color;
  final double base;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = base + (maxR - base) * p * (0.7 + 0.5 * amplitude);
      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - p)
          ..color = color.withValues(alpha: 0.42 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => true;
}
