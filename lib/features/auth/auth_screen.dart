import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/voix_button.dart';
import '../../core/widgets/voix_logo.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';
import '../onboarding/onboarding_draft.dart';
import '../shell/app_shell.dart';

/// Sign-in / sign-up.
///
/// Reached after onboarding, so the answers gathered there are already in
/// [onboardingDraftProvider] and get folded into the profile on success.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _obscure = true;
  bool _busy = false;
  AuthMethod? _pending;

  @override
  void initState() {
    super.initState();
    // Pre-fill from onboarding so a returning learner is not retyping.
    final draft = ref.read(onboardingDraftProvider);
    if (draft.name.isNotEmpty) _isSignUp = true;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _authenticate(AuthMethod method) async {
    if (_busy) return;

    if (method == AuthMethod.email &&
        !(_formKey.currentState?.validate() ?? false)) {
      Haptic.error();
      return;
    }

    setState(() {
      _busy = true;
      _pending = method;
    });

    try {
      final draft = ref.read(onboardingDraftProvider);
      final profile = await ref.read(authRepositoryProvider).signIn(
            method: method,
            email: _email.text.trim(),
            password: _password.text,
            name: draft.name,
            isSignUp: _isSignUp,
          );

      // A brand-new profile takes the onboarding answers; an existing one
      // keeps whatever the learner has already customised.
      final isNew = profile.xp == 0 && profile.totalConversations == 0;
      await ref
          .read(userControllerProvider.notifier)
          .setProfile(isNew ? draft.applyTo(profile) : profile);

      if (!mounted) return;
      Haptic.success();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      Haptic.error();
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      Haptic.error();
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final address = _email.text.trim();
    if (address.isEmpty) {
      Haptic.error();
      _showError('Enter your email address first, then tap Forgot password.');
      return;
    }

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(address);
      if (!mounted) return;
      Haptic.success();
      // Deliberately does not confirm whether an account exists: saying "no
      // such user" would let anyone test which email addresses are registered.
      _showError('If $address has an account, a reset link is on its way.');
    } on AuthException catch (e) {
      if (!mounted) return;
      Haptic.error();
      _showError(e.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: AuroraBackground(
        intensity: 1.2,
        child: SafeArea(
          child: GestureDetector(
            onTap: context.hideKeyboard,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.xl,
                Gap.page,
                Gap.xl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: context.screenH * 0.82),
                child: Column(
                  children: [
                    Gap.h24,
                    const FadeSlideIn(
                      offset: 0,
                      child: VoixWordmark(markSize: 52, fontSize: 34),
                    ),
                    Gap.h32,
                    FadeSlideIn(
                      index: 1,
                      child: Text(
                        _isSignUp ? 'Create your account' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: context.text.displaySmall,
                      ),
                    ),
                    Gap.h8,
                    FadeSlideIn(
                      index: 2,
                      child: Text(
                        _isSignUp
                            ? 'Save your streak, XP and progress.'
                            : 'Log in to continue your learning journey.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium,
                      ),
                    ),
                    Gap.h32,

                    // ── Social ────────────────────────────────────────
                    FadeSlideIn(
                      index: 3,
                      child: _SocialButton(
                        label: 'Continue with Google',
                        icon: Icons.g_mobiledata_rounded,
                        iconColor: const Color(0xFFEA4335),
                        loading: _busy && _pending == AuthMethod.google,
                        onTap: () => _authenticate(AuthMethod.google),
                      ),
                    ),
                    Gap.h12,
                    FadeSlideIn(
                      index: 4,
                      child: _SocialButton(
                        label: 'Continue with Apple',
                        icon: Icons.apple_rounded,
                        iconColor: c.textPrimary,
                        loading: _busy && _pending == AuthMethod.apple,
                        onTap: () => _authenticate(AuthMethod.apple),
                      ),
                    ),

                    Gap.h24,
                    FadeSlideIn(index: 5, child: const _OrDivider()),
                    Gap.h24,

                    // ── Email ─────────────────────────────────────────
                    FadeSlideIn(
                      index: 6,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              style: context.text.bodyLarge,
                              decoration: const InputDecoration(
                                hintText: 'Enter your email',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$')
                                    .hasMatch(value)) {
                                  return 'That does not look like a valid email';
                                }
                                return null;
                              },
                            ),
                            Gap.h12,
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                                  _authenticate(AuthMethod.email),
                              style: context.text.bodyLarge,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: Pressable(
                                  onTap: () =>
                                      setState(() => _obscure = !_obscure),
                                  scale: 0.85,
                                  semanticLabel: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  child: Icon(
                                    _obscure
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                    color: c.textTertiary,
                                  ),
                                ),
                              ),
                              validator: (v) => (v ?? '').length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!_isSignUp) ...[
                      Gap.h8,
                      FadeSlideIn(
                        index: 7,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Pressable(
                            onTap: _resetPassword,
                            scale: 0.94,
                            child: Padding(
                              padding: const EdgeInsets.all(Gap.xxs),
                              child: Text(
                                'Forgot password?',
                                style: context.text.labelMedium
                                    ?.copyWith(color: c.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    Gap.h24,
                    FadeSlideIn(
                      index: 8,
                      child: VoixButton(
                        label: _isSignUp ? 'Create Account' : 'Log In',
                        loading: _busy && _pending == AuthMethod.email,
                        onPressed: () => _authenticate(AuthMethod.email),
                      ),
                    ),
                    Gap.h16,

                    FadeSlideIn(
                      index: 9,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp
                                ? 'Already have an account?'
                                : "Don't have an account?",
                            style: context.text.bodySmall,
                          ),
                          Gap.w4,
                          Pressable(
                            onTap: () => setState(() => _isSignUp = !_isSignUp),
                            scale: 0.94,
                            child: Padding(
                              padding: const EdgeInsets.all(Gap.xxs),
                              child: Text(
                                _isSignUp ? 'Log in' : 'Sign up',
                                style: context.text.labelMedium?.copyWith(
                                  color: c.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Gap.h24,
                    FadeSlideIn(
                      index: 10,
                      child: VoixButton.ghost(
                        label: 'Continue as guest',
                        icon: Icons.explore_outlined,
                        expand: true,
                        loading: _busy && _pending == AuthMethod.guest,
                        onPressed: () => _authenticate(AuthMethod.guest),
                      ),
                    ),
                    Gap.h8,
                    Text(
                      'Guest progress stays on this device only.',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall
                          ?.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      onTap: loading ? null : onTap,
      radius: Radii.pill,
      fill: c.isDark ? c.surfaceHigh : c.surface,
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      semanticLabel: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(c.textSecondary),
              ),
            )
          else
            Icon(icon, size: 24, color: iconColor),
          Gap.w12,
          Text(
            label,
            style: context.text.labelLarge?.copyWith(
              color: c.textPrimary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget line(List<Color> colors) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
            ),
          ),
        );

    return Row(
      children: [
        line([c.border.withValues(alpha: 0), c.border]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          child: Text(
            'OR',
            style: context.text.labelSmall?.copyWith(
              color: c.textTertiary,
              letterSpacing: 1.4,
            ),
          ),
        ),
        line([c.border, c.border.withValues(alpha: 0)]),
      ],
    );
  }
}
