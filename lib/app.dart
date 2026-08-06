import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/context_ext.dart';
import 'core/utils/haptics.dart';
import 'features/splash/splash_screen.dart';
import 'providers/app_providers.dart';
import 'providers/user_controller.dart';

class VoixApp extends ConsumerWidget {
  const VoixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);

    // Haptics honour the learner's setting globally rather than at each call.
    ref.listen(userControllerProvider, (_, next) {
      Haptic.enabled = next?.hapticsEnabled ?? true;
    });

    return MaterialApp(
      title: 'Voix',
      debugShowCheckedModeBanner: false,
      theme: VoixTheme.light(),
      darkTheme: VoixTheme.dark(),
      themeMode: themeMode,
      home: const SplashScreen(),
      builder: (context, child) {
        // Clamp runaway system text scaling so fixed-height chrome (nav bar,
        // pills, score rings) stays intact while body copy still grows.
        final scale = context.textScaleClamped(max: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
