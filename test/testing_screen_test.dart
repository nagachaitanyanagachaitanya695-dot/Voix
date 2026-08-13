import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/config/backend_config.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/profile/testing_screen.dart';
import 'package:voix/providers/app_providers.dart';

/// The testing screen is the only route to the live call in a build made by
/// CI, because CI cannot compile in a backend address. If it fails to build,
/// the paid feature is untestable on a real phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
    BackendConfig.applyOverride();
  });

  tearDown(BackendConfig.applyOverride);

  Widget harness() => ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: const TestingScreen(),
        ),
      );

  testWidgets('renders with the fields needed to reach a backend',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Backend address'), findsOneWidget);
    expect(find.text('App token'), findsOneWidget);
    expect(find.text('Unlock Premium'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Check connection'),
        findsOneWidget);
  });

  testWidgets('saving an address makes the app consider itself configured',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(BackendConfig.isConfigured, isFalse);

    await tester.enterText(
      find.byType(TextField).first,
      'https://voix.example.workers.dev',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(BackendConfig.isConfigured, isTrue);
    expect(BackendConfig.sessionUrl.toString(),
        'https://voix.example.workers.dev/v1/session');
    expect(
      store.getString(LocalStore.kTestBackendUrl),
      isNotNull,
      reason: 'it has to survive a restart, or it must be retyped every launch',
    );
  });

  testWidgets('a pasted address keeps its trailing slash from breaking paths',
      (tester) async {
    // Copying a URL out of a browser address bar is the normal way to get one,
    // and the slash would otherwise produce //v1/session — a 404 that reads as
    // "the backend is down".
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).first,
      'https://voix.example.workers.dev/',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(BackendConfig.chatUrl.toString(),
        'https://voix.example.workers.dev/v1/chat');
  });

  test('a store release does not carry the testing screen', () {
    // Compiled off unless the build passes VOIX_TESTING, and `flutter test`
    // does not. If this ever reports true, a release build would ship a switch
    // that unlocks the paid interface.
    expect(BackendConfig.isTestingBuild, isFalse);
  });
}
