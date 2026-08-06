import 'package:flutter/material.dart';

/// Spacing scale. Every gap in the app comes from this ramp so vertical
/// rhythm stays consistent across screens.
abstract final class Gap {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Standard horizontal page padding.
  static const double page = 20;

  static const h4 = SizedBox(height: xxs);
  static const h8 = SizedBox(height: xs);
  static const h12 = SizedBox(height: sm);
  static const h16 = SizedBox(height: md);
  static const h20 = SizedBox(height: lg);
  static const h24 = SizedBox(height: xl);
  static const h32 = SizedBox(height: xxl);
  static const h40 = SizedBox(height: xxxl);

  static const w4 = SizedBox(width: xxs);
  static const w8 = SizedBox(width: xs);
  static const w12 = SizedBox(width: sm);
  static const w16 = SizedBox(width: md);
  static const w20 = SizedBox(width: lg);
}

/// Corner radii. Larger surfaces get larger radii so curvature reads as
/// consistent regardless of element size.
abstract final class Radii {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double sheet = 32;
  static const double pill = 999;

  static const rXs = BorderRadius.all(Radius.circular(xs));
  static const rSm = BorderRadius.all(Radius.circular(sm));
  static const rMd = BorderRadius.all(Radius.circular(md));
  static const rLg = BorderRadius.all(Radius.circular(lg));
  static const rXl = BorderRadius.all(Radius.circular(xl));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}

/// Motion tokens.
///
/// Durations are deliberately short — the reference material feels snappy,
/// not floaty. Anything above [slow] is reserved for the splash sequence.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 380);
  static const splash = Duration(milliseconds: 2800);

  /// Default easing for entrances and position changes.
  static const enter = Curves.easeOutCubic;

  /// For elements that should overshoot slightly — badges, score reveals.
  static const pop = Curves.easeOutBack;

  static const exit = Curves.easeInCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Per-item delay for staggered list entrances.
  static const staggerStep = Duration(milliseconds: 55);
}
