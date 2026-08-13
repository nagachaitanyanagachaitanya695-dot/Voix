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
  const plate = Color(0xFF080C1C);

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
      child: _Plate(size: legacy, plate: plate),
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
        child: VoixLogo(size: adaptive * (64 / 108)),
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
          size: adaptive * (62 / 108),
          filled: false,
          strokeScale: 1.15,
          gradient: const LinearGradient(colors: [Colors.white, Colors.white]),
          // The system tints this layer, so the bloom would only muddy it.
          glow: false,
        ),
      ),
    );
  });

  // Play requires exactly 512×512 for the store listing. Play rounds the
  // corners itself, so the plate runs edge to edge here rather than being
  // rounded like the legacy icon.
  _write(
    'play store listing icon',
    size: 512,
    path: '../store/play_icon_512.png',
    child: const _Plate(size: 512, plate: plate, radiusFactor: 0),
  );
}

/// The icon tile: dark plate, a lit top-left rim, and the mark.
///
/// The rim is what makes the supplied brand tile read as a lit object rather
/// than a flat square, so it is drawn rather than dropped.
class _Plate extends StatelessWidget {
  const _Plate({
    required this.size,
    required this.plate,
    this.radiusFactor = 0.22,
  });

  final double size;
  final Color plate;
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * radiusFactor);
    return DecoratedBox(
      decoration: BoxDecoration(color: plate, borderRadius: radius),
      child: Stack(
        children: [
          // The rim sits inside the plate edge, brightest at the top-left
          // where the brand gradient starts.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: GradientBoxBorder(
                  width: size * 0.012,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF22D3EE).withValues(alpha: 0.55),
                      const Color(0xFF3B82F6).withValues(alpha: 0.10),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.30),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Center(child: VoixLogo(size: size * 0.92)),
        ],
      ),
    );
  }
}

/// A [BoxBorder] painted with a gradient — Flutter's own [Border] only takes
/// flat colours, and the tile's rim has to run through the brand ramp.
class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({required this.gradient, required this.width});

  final Gradient gradient;
  final double width;

  @override
  BorderSide get bottom => BorderSide.none;
  @override
  BorderSide get top => BorderSide.none;
  @override
  bool get isUniform => true;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    // Inset by half the stroke so the whole rim lands inside the plate rather
    // than half of it bleeding off the edge of the PNG.
    final inner = rect.deflate(width / 2);
    if (borderRadius == null) {
      canvas.drawRect(inner, paint);
    } else {
      canvas.drawRRect(borderRadius.toRRect(inner), paint);
    }
  }

  @override
  ShapeBorder scale(double t) =>
      GradientBoxBorder(gradient: gradient, width: width * t);
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
