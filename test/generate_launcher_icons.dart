@Tags(['icons'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voix/core/widgets/voix_logo.dart';

/// Generates every Android launcher icon from the live [VoixLogo] painter, so
/// the home-screen icon and the in-app mark can never drift apart.
///
/// Run with:
///   flutter test test/generate_launcher_icons.dart --tags icons --update-goldens
///
/// Writes:
///   android/app/src/main/res/mipmap-*/ic_launcher.png            (legacy)
///   android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (adaptive)
///   android/app/src/main/res/mipmap-*/ic_launcher_monochrome.png (themed)
///   store/play_icon_512.png                                      (listing)
///
/// This piggybacks on the golden-file machinery purely as a PNG writer — with
/// `--update-goldens` it overwrites the targets rather than comparing against
/// them. It is tagged `icons` so `flutter test` never picks it up: without the
/// flag every one of these would run as an equality assertion on binary output,
/// which is not what the file is for.
void main() {
  // The icon plate, matching the near-black ground of the supplied brand icon.
  // Flat rather than a gradient so the adaptive background layer, which can
  // only be a single colour, stays identical to the legacy plate.
  const plate = Color(0xFF0B1022);

  /// Android's five bucket densities, as multiples of the mdpi baseline.
  const densities = <String, double>{
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  // Golden paths resolve relative to this file's directory.
  const res = '../android/app/src/main/res';

  densities.forEach((bucket, scale) {
    // Legacy icons are 48dp and unmasked, so the artwork supplies its own
    // rounded plate.
    final legacy = 48 * scale;
    _write(
      'legacy $bucket',
      size: legacy,
      path: '$res/mipmap-$bucket/ic_launcher.png',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: plate,
          borderRadius: BorderRadius.circular(legacy * 0.22),
        ),
        child: Center(child: VoixLogo(size: legacy * 0.74)),
      ),
    );

    // Adaptive layers are authored at 108dp; the launcher masks them down to a
    // 72dp visible area, so art must stay inside the centre 66dp or it will be
    // clipped on devices using a circular mask.
    final adaptive = 108 * scale;
    _write(
      'adaptive foreground $bucket',
      size: adaptive,
      path: '$res/mipmap-$bucket/ic_launcher_foreground.png',
      child: Center(
        child: VoixLogo(size: adaptive * (60 / 108)),
      ),
    );

    // The monochrome layer is tinted by the system for Android 13+ themed
    // icons, so only its alpha channel survives. The outline form reads far
    // better than the filled one once every colour collapses to one tint.
    _write(
      'adaptive monochrome $bucket',
      size: adaptive,
      path: '$res/mipmap-$bucket/ic_launcher_monochrome.png',
      child: Center(
        child: VoixLogo(
          size: adaptive * (58 / 108),
          filled: false,
          strokeScale: 1.15,
          gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
          // The system tints this layer, so the bloom would only muddy it.
          glow: false,
        ),
      ),
    );
  });

  // Play requires exactly 512×512 for the store listing.
  _write(
    'play store listing icon',
    size: 512,
    path: '../store/play_icon_512.png',
    child: ColoredBox(
      color: plate,
      child: const Center(child: VoixLogo(size: 368)),
    ),
  );
}

/// Renders [child] into a [size]×[size] surface and writes it to [path].
void _write(
  String name, {
  required double size,
  required String path,
  required Widget child,
}) {
  testWidgets(name, (tester) async {
    // dpr 1.0 makes the output pixel count equal the logical size, so `size`
    // is literally the width of the PNG.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(size, size);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: SizedBox.square(dimension: size, child: child),
        ),
      ),
    );

    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile(path));
  });
}
