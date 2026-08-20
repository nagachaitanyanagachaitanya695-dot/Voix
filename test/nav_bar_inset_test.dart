import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voix/core/theme/app_dimens.dart';
import 'package:voix/core/widgets/staggered.dart';
import 'package:voix/features/shell/app_shell.dart';

/// Two failures seen on a real phone, both of which left the app looking
/// broken while it was in fact working: navigation floating in the middle of
/// the screen, and page content stuck half-faded.
void main() {
  group('nav bar inset', () {
    testWidgets('honours an ordinary system inset', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
          child: MaterialApp(home: SizedBox()),
        ),
      );
      // The clamp must not interfere with a normal three-button bar.
      expect(48.0.clamp(0.0, maxSystemInset), 48.0);
    });

    test('refuses a nonsense inset', () {
      // The padding sits below the bar, so the reported inset is exactly how
      // far up the screen the bar floats. A phone claiming 460 puts the whole
      // navigation halfway up the page.
      expect(460.0.clamp(0.0, maxSystemInset), maxSystemInset);
      expect(maxSystemInset, lessThan(100),
          reason: 'no Android navigation area is anywhere near this');
    });
  });

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
