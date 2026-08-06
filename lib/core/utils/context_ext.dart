import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ergonomic accessors so widgets read `context.colors.textSecondary`
/// instead of the full `Theme.of(context).extension<VoixColors>()!` chain.
extension VoixContextX on BuildContext {
  VoixColors get colors => Theme.of(this).extension<VoixColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;

  Size get screen => MediaQuery.sizeOf(this);
  double get screenW => MediaQuery.sizeOf(this).width;
  double get screenH => MediaQuery.sizeOf(this).height;
  EdgeInsets get safeArea => MediaQuery.paddingOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// True on compact handsets (older/budget Android devices), where the
  /// layout drops to tighter padding and smaller hero elements.
  bool get isCompact => MediaQuery.sizeOf(this).width < 360;

  /// True on tablets and foldables in their unfolded state.
  bool get isWide => MediaQuery.sizeOf(this).width >= 600;

  /// Caps the OS text scale so very large accessibility settings enlarge copy
  /// without breaking fixed-height chrome like the nav bar.
  double textScaleClamped({double max = 1.3}) =>
      MediaQuery.textScalerOf(this).scale(1.0).clamp(1.0, max);

  void hideKeyboard() => FocusScope.of(this).unfocus();
}
