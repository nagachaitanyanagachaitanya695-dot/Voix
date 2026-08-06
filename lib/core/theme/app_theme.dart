import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Builds the light and dark [ThemeData] from the VOIX token layer.
abstract final class VoixTheme {
  static ThemeData dark() => _build(VoixColors.dark);
  static ThemeData light() => _build(VoixColors.light);

  static ThemeData _build(VoixColors c) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: VoixPalette.blue,
      onPrimary: Colors.white,
      primaryContainer: VoixPalette.indigo,
      onPrimaryContainer: Colors.white,
      secondary: VoixPalette.violet,
      onSecondary: Colors.white,
      secondaryContainer: VoixPalette.violet.withValues(alpha: 0.18),
      onSecondaryContainer: c.textPrimary,
      tertiary: VoixPalette.cyan,
      onTertiary: const Color(0xFF00202A),
      error: VoixPalette.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.borderStrong,
      shadow: c.shadow,
    );

    final text = VoixType.textTheme(c.textPrimary, c.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      textTheme: text,
      fontFamily: VoixType.display,
      extensions: [c],

      // Ripples are replaced by the scale-press interaction in `Pressable`,
      // so the default Material splash is suppressed app-wide.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle: c.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: c.textSecondary, size: 22),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.isDark ? c.surfaceHigh.withValues(alpha: 0.6) : c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.md,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: c.textTertiary),
        border: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: VoixPalette.blue, width: 1.6),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: VoixPalette.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: Radii.rMd,
          borderSide: BorderSide(color: VoixPalette.danger, width: 1.6),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? VoixPalette.blue
              : (c.isDark ? c.surfaceHigh : c.bgAlt),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.transparent : c.border,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rXl),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceHigh,
          borderRadius: Radii.rSm,
          border: Border.all(color: c.border),
        ),
        textStyle: text.labelMedium,
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Shared-axis style transition used for all pushed routes: the incoming page
/// fades up while the outgoing one settles back slightly.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Motion.enter);
    final leave = CurvedAnimation(parent: secondaryAnimation, curve: Motion.enter);

    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(enter),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.0).animate(leave),
          child: ScaleTransition(
            scale: Tween(begin: 1.0, end: 0.97).animate(leave),
            child: child,
          ),
        ),
      ),
    );
  }
}
