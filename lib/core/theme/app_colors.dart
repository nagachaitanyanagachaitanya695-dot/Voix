import 'package:flutter/material.dart';

/// The VOIX brand palette.
///
/// Brand hues are shared across both themes so the product reads as one
/// identity; only the neutral ramp flips between dark and light.
abstract final class VoixPalette {
  // ── Brand ──────────────────────────────────────────────────────────────
  /// The splash orb cyan — the "energy" end of the brand ramp.
  static const cyan = Color(0xFF22D8F0);
  static const blue = Color(0xFF3B7BFF);
  static const indigo = Color(0xFF5B5BFF);
  static const violet = Color(0xFF8B5CF6);
  static const magenta = Color(0xFFEC4899);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFF43F5E);
  static const streak = Color(0xFFFF7A2F);
  static const gold = Color(0xFFFFC53D);

  // ── Dark neutrals ──────────────────────────────────────────────────────
  static const darkBg = Color(0xFF04060F);
  static const darkBgAlt = Color(0xFF070B1A);
  static const darkSurface = Color(0xFF0D1225);
  static const darkSurfaceHigh = Color(0xFF141B33);
  static const darkBorder = Color(0xFF1E2745);
  static const darkTextPrimary = Color(0xFFF2F5FF);
  static const darkTextSecondary = Color(0xFF9AA6C7);
  static const darkTextTertiary = Color(0xFF64719A);

  // ── Light neutrals ─────────────────────────────────────────────────────
  static const lightBg = Color(0xFFF5F7FC);
  static const lightBgAlt = Color(0xFFEEF2FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE4E9F5);
  static const lightTextPrimary = Color(0xFF0A0F22);
  static const lightTextSecondary = Color(0xFF59637F);
  static const lightTextTertiary = Color(0xFF8A94AE);
}

/// Theme-dependent colour roles.
///
/// Exposed as a [ThemeExtension] so every widget can read the correct value
/// for the active brightness via `context.colors` without branching on
/// `Theme.of(context).brightness` at each call site.
@immutable
class VoixColors extends ThemeExtension<VoixColors> {
  const VoixColors({
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.glassFill,
    required this.glassStroke,
    required this.shadow,
    required this.brightness,
  });

  final Color bg;
  final Color bgAlt;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Translucent fill used by glass cards. Sits over [bg] gradients.
  final Color glassFill;

  /// 1px hairline that gives glass surfaces their lit top edge.
  final Color glassStroke;
  final Color shadow;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // Brand roles are constant across themes — surfaced here for convenience.
  Color get primary => VoixPalette.blue;
  Color get accent => VoixPalette.violet;
  Color get success => VoixPalette.success;
  Color get warning => VoixPalette.warning;
  Color get danger => VoixPalette.danger;
  Color get streak => VoixPalette.streak;
  Color get gold => VoixPalette.gold;

  static const dark = VoixColors(
    bg: VoixPalette.darkBg,
    bgAlt: VoixPalette.darkBgAlt,
    surface: VoixPalette.darkSurface,
    surfaceHigh: VoixPalette.darkSurfaceHigh,
    border: VoixPalette.darkBorder,
    borderStrong: Color(0xFF2C3961),
    textPrimary: VoixPalette.darkTextPrimary,
    textSecondary: VoixPalette.darkTextSecondary,
    textTertiary: VoixPalette.darkTextTertiary,
    glassFill: Color(0x0DFFFFFF),
    glassStroke: Color(0x1AFFFFFF),
    shadow: Color(0x9E000000),
    brightness: Brightness.dark,
  );

  static const light = VoixColors(
    bg: VoixPalette.lightBg,
    bgAlt: VoixPalette.lightBgAlt,
    surface: VoixPalette.lightSurface,
    surfaceHigh: VoixPalette.lightSurfaceHigh,
    border: VoixPalette.lightBorder,
    borderStrong: Color(0xFFD3DBEC),
    textPrimary: VoixPalette.lightTextPrimary,
    textSecondary: VoixPalette.lightTextSecondary,
    textTertiary: VoixPalette.lightTextTertiary,
    glassFill: Color(0xB3FFFFFF),
    glassStroke: Color(0xFFFFFFFF),
    shadow: Color(0x14101828),
    brightness: Brightness.light,
  );

  @override
  VoixColors copyWith({
    Color? bg,
    Color? bgAlt,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? glassFill,
    Color? glassStroke,
    Color? shadow,
    Brightness? brightness,
  }) {
    return VoixColors(
      bg: bg ?? this.bg,
      bgAlt: bgAlt ?? this.bgAlt,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      glassFill: glassFill ?? this.glassFill,
      glassStroke: glassStroke ?? this.glassStroke,
      shadow: shadow ?? this.shadow,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  VoixColors lerp(covariant VoixColors? other, double t) {
    if (other == null) return this;
    return VoixColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgAlt: Color.lerp(bgAlt, other.bgAlt, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassStroke: Color.lerp(glassStroke, other.glassStroke, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}
