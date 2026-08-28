import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voix/core/theme/app_dimens.dart';
import 'package:voix/core/widgets/staggered.dart';

/// An entrance animation must never be the thing hiding the content.
///
/// The nav bar's geometry is covered in navbar_position_test.dart, which
/// measures what was actually rendered. The clamp tests that used to live here
/// asserted Dart's own clamp() and would have passed with the app completely
/// broken, which is exactly what happened.
void main() {
  group('entrance animations', () {
    testWidgets('reveal content normally', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FadeSlideIn(index: 2, child: Text('hello')),
        ),
      );
      // Two pumps: the first lets the stagger timer fire and start the
      // controller, the second lets it run. One long pump only starts it.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));

      final opacity = tester.widget<FadeTransition>(
        find.byType(FadeTransition).first,
      );
      expect(opacity.opacity.value, 1.0);
    });

    testWidgets('reveal content even when no ticker ever runs', (tester) async {
      // A muted ticker leaves forward() doing nothing, so every wrapped widget
      // sits at zero opacity — a page that reads as dim and broken while
      // remaining fully interactive underneath. That is precisely what a
      // learner saw, and the failsafe sets the value directly, which needs no
      // ticker.
      await tester.pumpWidget(
        const MaterialApp(
          home: TickerMode(
            enabled: false,
            child: FadeSlideIn(index: 3, child: Text('hello')),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      var opacity = tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value;
      expect(opacity, lessThan(1.0), reason: 'a muted ticker cannot animate');

      // Past the stagger, the duration and the grace period.
      await tester.pump(
        Motion.staggerStep * 3 + Motion.slow + const Duration(seconds: 1),
      );
      await tester.pump();

      opacity = tester
          .widget<FadeTransition>(find.byType(FadeTransition).first)
          .opacity
          .value;
      expect(opacity, 1.0, reason: 'content must never stay hidden');
    });
  });
}
