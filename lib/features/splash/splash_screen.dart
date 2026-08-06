import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/energy_orb.dart';
import '../../core/widgets/voix_logo.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';
import '../auth/auth_screen.dart';
import '../onboarding/onboarding_flow.dart';
import '../shell/app_shell.dart';

/// The launch sequence.
///
/// An energy orb ignites, collapses into the VOIX mark as it draws itself
/// stroke by stroke, then the wordmark resolves — the same beat structure as
/// the reference animation, rebuilt as vector paths so it costs one texture
/// and ships in kilobytes rather than as a video.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.splash,
  );

  // ── Timeline ─────────────────────────────────────────────────────────
  // Overlapping intervals keep the sequence continuous: each element begins
  // before the previous has settled.
  late final _orbIn = _curve(0.00, 0.22, Curves.easeOutCubic);
  late final _orbOut = _curve(0.30, 0.52, Curves.easeInCubic);
  late final _logoDraw = _curve(0.26, 0.62, Curves.easeInOutCubic);
  late final _logoFill = _curve(0.58, 0.72, Curves.easeOutCubic);
  late final _flash = _curve(0.56, 0.68, Curves.easeOut);
  late final _wordIn = _curve(0.66, 0.84, Curves.easeOutCubic);
  late final _taglineIn = _curve(0.78, 0.94, Curves.easeOutCubic);

  Animation<double> _curve(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _advance();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted) return;

    final onboarded = ref.read(onboardingControllerProvider);
    final signedIn = ref.read(userControllerProvider) != null;

    final Widget next;
    if (!onboarded) {
      next = const OnboardingFlow();
    } else if (!signedIn) {
      next = const AuthScreen();
    } else {
      next = const AppShell();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 620),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = (context.screenW * 0.78).clamp(220.0, 340.0);
    final markSize = (context.screenW * 0.30).clamp(96.0, 150.0);

    return Scaffold(
      backgroundColor: VoixPalette.darkBg,
      body: AuroraBackground(
        intensity: 1.4,
        colors: const [VoixPalette.cyan, VoixPalette.violet],
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // The orb blooms, then collapses inward as the mark takes over.
            final orbEnergy = _orbIn.value * (1 - _orbOut.value);
            final orbScale = 1.0 - 0.45 * _orbOut.value;

            return Stack(
              alignment: Alignment.center,
              children: [
                // ── Orb ──────────────────────────────────────────────
                if (orbEnergy > 0.01)
                  Transform.scale(
                    scale: orbScale,
                    child: EnergyOrb(
                      size: orbSize,
                      energy: orbEnergy,
                      amplitude: 0.45 + 0.35 * _orbIn.value,
                    ),
                  ),

                // ── Ignition flash at the hand-off ───────────────────
                if (_flash.value > 0 && _flash.value < 1)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(
                              alpha: 0.55 *
                                  (1 - (_flash.value * 2 - 1).abs()),
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),

                // ── Mark + wordmark ──────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: _logoDraw.value == 0 ? 0 : 1,
                      child: Transform.scale(
                        scale: 0.9 + 0.1 * _logoDraw.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outline draws itself…
                            Opacity(
                              opacity: 1 - _logoFill.value,
                              child: VoixLogo(
                                size: markSize,
                                filled: false,
                                drawProgress: _logoDraw.value,
                                strokeScale: 0.9,
                              ),
                            ),
                            // …then the solid mark cross-fades in.
                            Opacity(
                              opacity: _logoFill.value,
                              child: VoixLogo(
                                size: markSize,
                                filled: true,
                                cutoutColor: VoixPalette.darkBg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: markSize * 0.18),
                    Opacity(
                      opacity: _wordIn.value,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - _wordIn.value)),
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (b) => VoixGradients.brand
                              .createShader(
                                  Rect.fromLTWH(0, 0, b.width, b.height)),
                          child: Text(
                            'Voix',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: markSize * 0.42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Gap.h12,
                    Opacity(
                      opacity: _taglineIn.value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - _taglineIn.value)),
                        child: Text(
                          'Your Personal AI Language Tutor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: VoixPalette.darkTextSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
