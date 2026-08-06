import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared gradient definitions.
///
/// The brand ramp runs cyan → blue → violet, mirroring the splash animation
/// where the energy orb cools from cyan into the violet wordmark glow.
abstract final class VoixGradients {
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [VoixPalette.cyan, VoixPalette.blue, VoixPalette.violet],
    stops: [0.0, 0.55, 1.0],
  );

  static const brandSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4AA8FF), VoixPalette.indigo],
  );

  static const violetMagenta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [VoixPalette.violet, VoixPalette.magenta],
  );

  static const flame = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB020), VoixPalette.streak],
  );

  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF0EA5A5)],
  );

  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD873), Color(0xFFE8A020)],
  );

  /// Radial glow placed behind the mic / orb elements.
  static RadialGradient glow(Color color, {double intensity = 0.55}) {
    return RadialGradient(
      colors: [
        color.withValues(alpha: intensity),
        color.withValues(alpha: intensity * 0.35),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    );
  }

  /// The ambient page backdrop: a deep vertical wash plus two off-screen
  /// colour blooms. Rendered by `AuroraBackground`.
  static LinearGradient page(VoixColors c) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: c.isDark
          ? [c.bgAlt, c.bg, c.bg]
          : [c.bgAlt, c.bg, c.bg],
      stops: const [0.0, 0.45, 1.0],
    );
  }
}
