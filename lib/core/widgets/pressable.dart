import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../utils/haptics.dart';

/// Replaces the Material ink ripple with a scale-down press.
///
/// Every tappable surface in VOIX routes through this so the whole app shares
/// one physical-feeling response instead of mixing ripples with custom states.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
    this.borderRadius,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Depth of the press. Large surfaces use a shallower value (0.97–0.98) so
  /// the movement stays proportional to the element.
  final double scale;
  final bool haptic;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 190),
  );

  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: widget.scale,
  ).animate(CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  ));

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) {
    if (!_interactive) return;
    _c.forward();
  }

  void _up([_]) {
    if (!_interactive) return;
    _c.reverse();
  }

  void _tap() {
    if (!_interactive) return;
    if (widget.haptic) Haptic.tap();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: _interactive,
      label: widget.semanticLabel,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _up,
        onTap: _tap,
        onLongPress: _interactive
            ? () {
                if (widget.haptic) Haptic.medium();
                widget.onLongPress?.call();
              }
            : null,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedOpacity(
            duration: Motion.fast,
            opacity: widget.enabled ? 1.0 : 0.45,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
