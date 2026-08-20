import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// Fades and lifts a widget into place on first build.
///
/// Wrapping the children of a screen with an increasing [index] produces the
/// cascade used on every scrollable page — content arrives in reading order
/// rather than all at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 24,
    this.duration = Motion.slow,
    this.delay = Duration.zero,
    this.horizontal = false,
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;
  final Duration delay;
  final bool horizontal;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Held so the stagger delay can be cancelled — a bare `Future.delayed`
  /// would keep firing after the widget is gone.
  Timer? _startTimer;

  /// Shows the content outright if the animation never runs.
  ///
  /// `forward()` only advances while the widget's ticker is ticking, and a
  /// ticker is muted whenever its subtree is not animating — an offstage
  /// route, a paused page, some device states. When that happens the
  /// controller sits at zero and every widget wrapped in this stays at low
  /// opacity: a page that reads as dim and broken while remaining fully
  /// interactive underneath.
  ///
  /// Setting `value` directly needs no ticker, so this cannot be defeated the
  /// same way. An entrance animation is decoration; the content is not, and it
  /// must never be what hides it.
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    final wait = widget.delay + Motion.staggerStep * widget.index;
    if (wait == Duration.zero) {
      _c.forward();
    } else {
      _startTimer = Timer(wait, () {
        if (mounted) _c.forward();
      });
    }
    _failsafe = Timer(wait + widget.duration + _failsafeGrace, () {
      if (mounted && _c.value < 1.0) _c.value = 1.0;
    });
  }

  static const _failsafeGrace = Duration(milliseconds: 600);

  @override
  void dispose() {
    _startTimer?.cancel();
    _failsafe?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Motion.enter);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (_, child) => Transform.translate(
          offset: widget.horizontal
              ? Offset(widget.offset * (1 - curved.value), 0)
              : Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Animates an integer from its previous value to [value] — used for XP,
/// streak days, and score counters so numbers roll rather than snap.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.prefix = '',
    this.suffix = '',
    this.separator = true,
  });

  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  /// Insert thousands separators (1250 → 1,250).
  final bool separator;

  static String format(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final n = v.round();
        return Text(
          '$prefix${separator ? format(n) : n.toString()}$suffix',
          style: style,
        );
      },
    );
  }
}
