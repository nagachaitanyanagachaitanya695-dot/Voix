import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/repositories/local_store.dart';
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

  final container = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
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
