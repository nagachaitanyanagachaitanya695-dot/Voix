import 'package:flutter/material.dart';

/// Typography scale.
///
/// Two families do all the work: [display] (Plus Jakarta Sans) carries UI and
/// headings, while [numeric] (Manrope) is reserved for figures — XP, streak
/// counts, scores — where its tighter forms keep large numbers compact.
abstract final class VoixType {
  static const display = 'PlusJakartaSans';
  static const numeric = 'Manrope';

  static TextTheme textTheme(Color primary, Color secondary) {
    TextStyle base(
      double size,
      FontWeight weight, {
      double? height,
      double? letterSpacing,
      Color? color,
    }) {
      return TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? primary,
      );
    }

    return TextTheme(
      // Reserved for the splash wordmark and onboarding hero lines.
      displayLarge: base(40, FontWeight.w800, height: 1.1, letterSpacing: -1.0),
      displayMedium: base(34, FontWeight.w800, height: 1.12, letterSpacing: -0.8),
      displaySmall: base(28, FontWeight.w700, height: 1.18, letterSpacing: -0.6),

      // Screen titles and card headings.
      headlineMedium: base(24, FontWeight.w700, height: 1.2, letterSpacing: -0.4),
      headlineSmall: base(20, FontWeight.w700, height: 1.25, letterSpacing: -0.3),
      titleLarge: base(18, FontWeight.w700, height: 1.3, letterSpacing: -0.2),
      titleMedium: base(16, FontWeight.w600, height: 1.35, letterSpacing: -0.1),
      titleSmall: base(14, FontWeight.w600, height: 1.4),

      // Body copy.
      bodyLarge: base(16, FontWeight.w400, height: 1.5, color: primary),
      bodyMedium: base(14, FontWeight.w400, height: 1.5, color: secondary),
      bodySmall: base(13, FontWeight.w400, height: 1.45, color: secondary),

      // Buttons, chips, captions.
      labelLarge: base(15, FontWeight.w700, height: 1.2, letterSpacing: 0.1),
      labelMedium: base(13, FontWeight.w600, height: 1.2, letterSpacing: 0.2),
      labelSmall: base(11, FontWeight.w600, height: 1.2, letterSpacing: 0.4, color: secondary),
    );
  }

  /// Large figures — XP totals, streak days, score rings.
  static TextStyle stat(double size, {Color? color, FontWeight weight = FontWeight.w800}) {
    return TextStyle(
      fontFamily: numeric,
      fontSize: size,
      fontWeight: weight,
      height: 1.0,
      letterSpacing: -0.5,
      color: color,
    );
  }
}
