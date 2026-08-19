import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voix/core/config/backend_config.dart';
import 'package:voix/core/theme/app_theme.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/repositories/local_store.dart';
import 'package:voix/features/learn/word_sheet.dart';
import 'package:voix/providers/app_providers.dart';

/// Looking up a word has to work with no backend, because that is the state
/// every install starts in and the state most of them stay in. A sheet that
/// shows a spinner and then nothing would make the feature look broken rather
/// than partial.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const learner = UserProfile(id: 'u1', name: 'Chaitanya');

  setUp(() {
    BackendConfig.applyOverride();
    SharedPreferences.setMockInitialValues({
      LocalStore.kSignedIn: true,
      LocalStore.kOnboarded: true,
      LocalStore.kProfile: jsonEncode(learner.toJson()),
    });
  });

  Future<void> open(WidgetTester tester, String word) async {
    final store = await LocalStore.open();
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        firebaseReadyProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: VoixTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showWordSheet(context, word),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows an irregular verb\'s forms with no backend',
      (tester) async {
    await open(tester, 'go');

    expect(find.text('go'), findsOneWidget);
    expect(find.text('Other forms'.toUpperCase()), findsOneWidget);
    // The forms are the whole offline answer, and the part a learner whose
    // language marks tense differently actually came for.
    expect(find.text('went'), findsOneWidget);
    expect(find.text('gone'), findsOneWidget);
    expect(find.text('going'), findsOneWidget);
  });

  testWidgets('says what is missing rather than pretending that is all',
      (tester) async {
    await open(tester, 'go');

    expect(
      find.textContaining('need the tutor to be set up'),
      findsOneWidget,
      reason: 'a thin answer presented as the whole answer is misleading',
    );
  });

  testWidgets('does not show a meaning section it has nothing to fill',
      (tester) async {
    await open(tester, 'go');
    expect(find.text('Meaning'.toUpperCase()), findsNothing);
  });

  testWidgets('opens for a word with nothing to inflect', (tester) async {
    // No forms, no backend: the sheet must still open and explain itself
    // rather than rendering an empty box.
    await open(tester, 'the');
    expect(find.text('the'), findsOneWidget);
    expect(find.textContaining('need the tutor'), findsOneWidget);
  });
}
