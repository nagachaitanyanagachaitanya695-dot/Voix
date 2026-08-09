import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repositories/local_store.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'providers/user_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage is opened before the first frame so every controller can read
  // synchronously — the app boots straight into real content instead of
  // flashing a loading state over the splash animation.
  final store = await LocalStore.open();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Firebase is optional. An unconfigured project, a missing network at first
  // launch, or a botched google-services setup must all end the same way: the
  // app starts on local accounts rather than showing a crash screen to someone
  // who only wanted to practise their English.
  var firebaseReady = false;
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase initialisation failed ($e) — using local accounts');
    }
  }

  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      firebaseReadyProvider.overrideWithValue(firebaseReady),
    ],
  );

  // Reminders are re-synced at every launch rather than only when a switch is
  // touched: the schedule lives in the OS, and an uninstall/reinstall, a
  // "clear data", or a reboot on some vendors' Android builds all wipe it
  // while the learner's preference here still says reminders are on.
  final user = container.read(userControllerProvider);
  if (user != null) {
    unawaited(container.read(notificationServiceProvider).sync(user));
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VoixApp(),
    ),
  );
}
