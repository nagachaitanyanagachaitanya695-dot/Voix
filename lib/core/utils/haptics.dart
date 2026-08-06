import 'package:flutter/services.dart';

/// Thin wrapper over [HapticFeedback] giving each interaction class a named
/// intent, so feedback stays consistent app-wide and can be muted in one place.
abstract final class Haptic {
  static bool enabled = true;

  /// Taps on cards, chips, list rows.
  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Primary button presses, mode switches.
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Recording start/stop, sheet commit.
  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Level-up, achievement unlock, streak milestone.
  static void success() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// Wrong answer, validation failure.
  static void error() {
    if (enabled) HapticFeedback.vibrate();
  }
}
