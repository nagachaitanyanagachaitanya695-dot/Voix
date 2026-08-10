import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/voix_button.dart';
import '../../data/services/subscription_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';

/// The Voix Premium paywall.
///
/// Prices are read from Play rather than written here. Play knows what this
/// learner will actually be charged in their currency, including the
/// introductory first week; a hardcoded price shown to someone billed
/// something else earns refunds and one-star reviews.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  late final SubscriptionService _subs;
  StreamSubscription<bool>? _entitlementSub;

  @override
  void initState() {
    super.initState();
    _subs = ref.read(subscriptionServiceProvider);

    _entitlementSub = _subs.entitlements.listen((granted) {
      if (!granted || !mounted) return;
      // The server confirmed it. Record it locally so the rest of the app
      // unlocks, and get out of the way.
      unawaited(
        ref.read(userControllerProvider.notifier).update(
              (u) => u.copyWith(isPro: true),
            ),
      );
      Haptic.success();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Welcome to Voix Premium.')),
        );
      Navigator.of(context).maybePop();
    });

    unawaited(_subs.init(userId: ref.read(userControllerProvider)?.id));
  }

  @override
  void dispose() {
    _entitlementSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.sm),
                  child: Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xxs),
                      child: Icon(Icons.close_rounded, color: c.textSecondary),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    0,
                    Gap.page,
                    Gap.lg,
                  ),
                  children: [
                    GradientText(
                      'Voix Premium',
                      style: context.text.displaySmall,
                      gradient: VoixGradients.brand,
                    ),
                    Gap.h8,
                    Text(
                      'Talk to your tutor out loud, the way you would talk to '
                      'a person.',
                      style: context.text.bodyLarge?.copyWith(height: 1.5),
                    ),
                    Gap.h24,
                    const _Benefit(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Live voice conversation',
                      detail:
                          'Speak and be answered straight away — no waiting, '
                          'no typing. Interrupt whenever you like.',
                      color: VoixPalette.cyan,
                    ),
                    const _Benefit(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Every scenario and lesson',
                      detail: 'Interviews, travel, roleplay — the whole '
                          'catalogue, unlocked.',
                      color: VoixPalette.violet,
                    ),
                    const _Benefit(
                      icon: Icons.translate_rounded,
                      title: 'Explanations in your language',
                      detail:
                          'Stuck on something? Have it explained in Telugu, '
                          'Hindi or Tamil, then carry on in English.',
                      color: VoixPalette.magenta,
                    ),
                    Gap.h24,
                    _priceCard(c),
                    Gap.h20,
                    ValueListenableBuilder<SubscriptionState>(
                      valueListenable: _subs.state,
                      builder: (context, state, _) => _actions(state),
                    ),
                    Gap.h12,
                    ValueListenableBuilder<String?>(
                      valueListenable: _subs.lastError,
                      builder: (context, error, _) => error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: Gap.sm),
                              child: Text(
                                error,
                                textAlign: TextAlign.center,
                                style: context.text.bodySmall
                                    ?.copyWith(color: c.danger, height: 1.45),
                              ),
                            ),
                    ),
                    Text(
                      'Billed through Google Play. Cancel any time in the Play '
                      'Store — you keep access until the period you have paid '
                      'for ends.',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceCard(VoixColors c) {
    return GlassCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: ValueListenableBuilder<String?>(
        valueListenable: _subs.price,
        builder: (context, price, _) => Column(
          children: [
            Text('First week', style: context.text.labelMedium),
            Gap.h4,
            GradientText(
              '₹9',
              style: context.text.displayMedium,
              gradient: VoixGradients.brand,
            ),
            Gap.h8,
            Text(
              // Falls back to plain wording until Play answers, rather than
              // showing a price that might not be this learner's.
              price == null
                  ? 'then the monthly price, billed monthly'
                  : 'then $price a month',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(SubscriptionState state) {
    if (state == SubscriptionState.unavailable) {
      return Column(
        children: [
          Text(
            'Subscriptions are not available on this device right now.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium,
          ),
          Gap.h8,
          Text(
            'Make sure the Play Store is signed in and up to date.',
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(height: 1.45),
          ),
        ],
      );
    }

    final busy = state == SubscriptionState.pending ||
        state == SubscriptionState.loading;

    return Column(
      children: [
        VoixButton(
          label: state == SubscriptionState.pending
              ? 'Waiting for payment…'
              : 'Start for ₹9',
          loading: busy,
          onPressed: busy ? null : () => unawaited(_subs.subscribe()),
        ),
        if (state == SubscriptionState.pending) ...[
          Gap.h8,
          Text(
            'A UPI payment can take a few minutes to confirm. You can leave '
            'this screen — we will unlock it as soon as it goes through.',
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(height: 1.45),
          ),
        ],
        Gap.h8,
        Pressable(
          onTap: () => unawaited(_subs.restore()),
          child: Padding(
            padding: const EdgeInsets.all(Gap.xs),
            child: Text(
              'Restore purchases',
              style: context.text.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Gap.h4,
                Text(
                  detail,
                  style: context.text.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
