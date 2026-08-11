import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';
import '../utils/context_ext.dart';
import '../utils/haptics.dart';

/// One column of the weekly activity chart.
class BarDatum {
  const BarDatum({required this.label, required this.value});
  final String label;
  final double value;
}

/// Hand-rolled bar chart for weekly practice minutes.
///
/// Built as a widget tree rather than a `CustomPaint` so each bar can own its
/// own implicit animation and hit target — that keeps the grow-in stagger and
/// the tap-to-select tooltip simple, and avoids pulling in a charting
/// dependency for one visual.
class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({
    super.key,
    required this.data,
    this.height = 170,
    this.selectedIndex,
    this.showAxis = true,
    this.unitLabel = 'min',
  });

  final List<BarDatum> data;
  final double height;

  /// Pre-selected column (defaults to the highest value).
  final int? selectedIndex;
  final bool showAxis;
  final String unitLabel;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  int? _selected;
  bool _grown = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIndex;
    // Bars start at zero height and grow on the first frame after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _grown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = widget.data.map((d) => d.value).toList();
    final rawMax = values.isEmpty ? 0.0 : values.reduce(math.max);
    // Round the axis up to a clean step so gridlines land on tidy numbers.
    final step = rawMax <= 10 ? 5.0 : (rawMax <= 30 ? 10.0 : 20.0);
    final maxY = math.max(step, (rawMax / step).ceil() * step);

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showAxis) ...[
            _AxisLabels(maxY: maxY, step: step),
            Gap.w8,
          ],
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: 22,
                  child: _Gridlines(maxY: maxY, step: step, color: c.border),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(widget.data.length, (i) {
                    return Expanded(
                      child: _Bar(
                        datum: widget.data[i],
                        maxY: maxY,
                        grown: _grown,
                        index: i,
                        selected: _selected == i,
                        unitLabel: widget.unitLabel,
                        onTap: () {
                          Haptic.tap();
                          setState(() => _selected = _selected == i ? null : i);
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.maxY, required this.step});
  final double maxY;
  final double step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = (maxY / step).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = count; i >= 0; i--)
            Text(
              '${(step * i).round()}',
              style: context.text.labelSmall?.copyWith(color: c.textTertiary),
            ),
        ],
      ),
    );
  }
}

class _Gridlines extends StatelessWidget {
  const _Gridlines({
    required this.maxY,
    required this.step,
    required this.color,
  });
  final double maxY;
  final double step;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final count = (maxY / step).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i <= count; i++)
          Container(height: 1, color: color.withValues(alpha: 0.55)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.datum,
    required this.maxY,
    required this.grown,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.unitLabel,
  });

  final BarDatum datum;
  final double maxY;
  final bool grown;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = maxY == 0 ? 0.0 : (datum.value / maxY).clamp(0.0, 1.0);
    final isEmpty = datum.value <= 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        label: '${datum.label}: ${datum.value.round()} $unitLabel',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) {
                  // The value rides directly on top of its own bar, so the
                  // numbers step up and down with the week rather than sitting
                  // in a detached row. Reserving the label's height keeps a
                  // full-height bar from pushing its own number off the top.
                  const labelHeight = 20.0;
                  final usable = math.max(0.0, box.maxHeight - labelHeight);
                  final target = grown ? usable * ratio : 0.0;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: labelHeight,
                          child: AnimatedOpacity(
                            duration: Motion.base,
                            opacity: isEmpty ? 0.0 : 1.0,
                            child: Text(
                              '${datum.value.round()}',
                              style: context.text.labelSmall?.copyWith(
                                color: selected
                                    ? c.textPrimary
                                    : c.textSecondary,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 600 + index * 60),
                          curve: Curves.easeOutCubic,
                          height: math.max(target, isEmpty ? 3 : 6),
                          width: 18,
                          decoration: BoxDecoration(
                            gradient: isEmpty
                                ? null
                                : (selected
                                    ? VoixGradients.brand
                                    : LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          VoixPaletteRef.barTop,
                                          VoixPaletteRef.barBottom,
                                        ],
                                      )),
                            color: isEmpty ? c.border : null,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color:
                                          c.primary.withValues(alpha: 0.45),
                                      blurRadius: 14,
                                      spreadRadius: -3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Gap.h4,
            SizedBox(
              height: 16,
              child: Text(
                datum.label,
                style: context.text.labelSmall?.copyWith(
                  color: selected ? c.textPrimary : c.textTertiary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar fill colours, kept next to the chart because they are specific to it.
abstract final class VoixPaletteRef {
  static const barTop = Color(0xFF5B7BFF);
  static const barBottom = Color(0xFF3B3BE8);
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.label,
    this.size = 88,
    this.color,
  });

  /// 0–100.
  final int score;
  final String label;
  final double size;
  final Color? color;

  Color _tint(BuildContext context) {
    if (color != null) return color!;
    final c = context.colors;
    if (score >= 80) return c.success;
    if (score >= 60) return c.primary;
    if (score >= 40) return c.warning;
    return c.danger;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = _tint(context);

    return Semantics(
      label: '$label $score out of 100',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(size),
                    painter: _RingPainter(
                      progress: v,
                      track: c.border,
                      tint: tint,
                      stroke: size * 0.09,
                    ),
                  ),
                  Text(
                    '${(v * 100).round()}',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap.h8,
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.tint,
    required this.stroke,
  });

  final double progress;
  final Color track;
  final Color tint;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: centre, radius: r);

    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [tint.withValues(alpha: 0.55), tint],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.tint != tint;
}
