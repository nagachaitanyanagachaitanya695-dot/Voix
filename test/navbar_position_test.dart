import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/shell/app_shell.dart';
import 'package:voix/providers/app_providers.dart';

/// The navigation bar appeared halfway up the screen on a real phone, with
/// every page behind it washed out — two symptoms, one cause.
///
/// _NavButton centred its content in a bare [Center], which expands to fill
/// whatever it is offered, and Scaffold offers the bottom slot the whole
/// screen. The bar grew to 839 of 915 logical pixels and centred its icons in
/// the middle of that; because extendBody draws the bar over the body, its
/// near-opaque background then covered the page and made everything look
/// faded.
///
/// This measures the rendered geometry rather than the arithmetic, which is
/// the only way that fault was ever going to be caught: every value feeding
/// the layout was correct.
void main() {
  testWidgets('nav bar stays at the bottom despite an absurd inset',
      (tester) async {
    const learner = UserProfile(id: 'u1', name: 'Bittu');
    SharedPreferences.setMockInitialValues({
      LocalStore.kSignedIn: true,
      LocalStore.kOnboarded: true,
      LocalStore.kProfile: jsonEncode(learner.toJson()),
    });
    final store = await LocalStore.open();
    final container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      firebaseReadyProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: const MediaQuery(
            // What the phone appears to be reporting.
            data: MediaQueryData(
              size: Size(412, 915),
              padding: EdgeInsets.only(bottom: 400),
              viewPadding: EdgeInsets.only(bottom: 400),
            ),
            child: AppShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));

    final box = tester.renderObject<RenderBox>(find.byKey(navBarPaddingKey));
    final topLeft = box.localToGlobal(Offset.zero);
    expect(box.size.height, lessThan(160),
        reason: 'the bar plus its inset must not be a fifth of the screen');
    expect(topLeft.dy, greaterThan(700),
        reason: 'the bar must sit near the bottom, not mid-screen');
  });
}
