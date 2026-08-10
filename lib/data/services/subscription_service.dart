import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/config/backend_config.dart';

/// Where the subscription flow currently is.
enum SubscriptionState {
  /// Still working out whether billing is usable and what it costs.
  loading,

  /// Billing is ready and the learner is not subscribed.
  available,

  /// A purchase is in flight, or is awaiting approval (UPI mandates and
  /// parental approval can both leave a purchase pending for hours).
  pending,

  /// Subscribed. This is the client's belief; the server decides for real.
  subscribed,

  /// Billing is not usable on this device at all.
  unavailable,
}

/// Voix Premium, through Google Play Billing.
///
/// Play is used rather than a payment page on the website for two reasons: it
/// supports UPI in India, and selling an in-app feature through anything else
/// is a Play payments-policy problem that gets apps removed after launch.
///
/// **A purchase here is a claim, not proof.** Everything this class produces is
/// forwarded to the backend, which asks Google directly whether the token is
/// real and still active. The app's own `isPro` flag only controls what the UI
/// offers; the server independently refuses premium work to accounts it has
/// not verified. Anyone can unzip an APK and flip a boolean — they cannot flip
/// one on your Worker.
class SubscriptionService {
  SubscriptionService({
    InAppPurchase? billing,
    http.Client? httpClient,
    Uri? verifyEndpoint,
  })  : _billing = billing ?? InAppPurchase.instance,
        _http = httpClient ?? http.Client(),
        _verifyEndpoint = verifyEndpoint;

  final InAppPurchase _billing;
  final http.Client _http;

  /// Overrides [BackendConfig.verifyUrl]. Injected by tests so the grant and
  /// refuse paths can be exercised without a deployed backend.
  final Uri? _verifyEndpoint;

  Uri? get _verifyUrl {
    if (_verifyEndpoint != null) return _verifyEndpoint;
    return BackendConfig.isConfigured ? BackendConfig.verifyUrl : null;
  }

  /// The subscription's product id in Play Console. The ₹9 first week is an
  /// *introductory price* configured on this same subscription's base plan —
  /// not a second product — so Play handles the transition to ₹299/month and
  /// the app never has to reason about which period the learner is in.
  static const productId = 'voix_premium';

  final state = ValueNotifier(SubscriptionState.loading);

  /// The localised price to show on the paywall, e.g. "₹299.00".
  ///
  /// Always taken from Play rather than hardcoded: prices differ by country,
  /// and a hardcoded "₹299" shown to someone being charged something else is
  /// the kind of thing that gets refunds and one-star reviews.
  final price = ValueNotifier<String?>(null);

  /// Set when a purchase fails for a reason worth showing the learner.
  final lastError = ValueNotifier<String?>(null);

  /// Fires when the backend confirms a subscription, so the profile can be
  /// updated and premium features unlocked.
  Stream<bool> get entitlements => _entitlements.stream;
  final _entitlements = StreamController<bool>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  /// The account this device is signed in as, sent with verification so the
  /// entitlement is attached to the account rather than the handset.
  String? userId;

  Future<void> init({String? userId}) async {
    this.userId = userId;

    try {
      if (!await _billing.isAvailable()) {
        state.value = SubscriptionState.unavailable;
        return;
      }

      _sub = _billing.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          debugPrint('SubscriptionService: purchase stream error ($e)');
          lastError.value = 'Something went wrong with the payment.';
        },
      );

      final response = await _billing.queryProductDetails({productId});
      if (response.productDetails.isEmpty) {
        // Almost always a Play Console configuration problem rather than a
        // code one: the subscription is not active, or the build is not signed
        // with the key the Play listing expects.
        debugPrint('SubscriptionService: product "$productId" not found — '
            'notFoundIDs=${response.notFoundIDs}');
        state.value = SubscriptionState.unavailable;
        return;
      }

      _product = response.productDetails.first;
      price.value = _product!.price;
      state.value = SubscriptionState.available;
    } catch (e) {
      debugPrint('SubscriptionService: init failed ($e)');
      state.value = SubscriptionState.unavailable;
    }
  }

  /// Opens Play's purchase sheet.
  Future<void> subscribe() async {
    final product = _product;
    if (product == null) {
      lastError.value = 'Subscriptions are not available right now.';
      return;
    }

    lastError.value = null;
    state.value = SubscriptionState.pending;

    try {
      // Subscriptions go through buyNonConsumable — buyConsumable is for
      // things that are used up and bought again.
      await _billing.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: userId,
        ),
      );
    } catch (e) {
      debugPrint('SubscriptionService: buy failed ($e)');
      lastError.value = 'The payment could not be started.';
      state.value = SubscriptionState.available;
    }
  }

  /// Re-delivers a subscription bought on another device or before a reinstall.
  ///
  /// Play requires this to be reachable from the UI: someone who has paid and
  /// reinstalled must be able to get their subscription back without paying
  /// again.
  Future<void> restore() async {
    try {
      await _billing.restorePurchases();
    } catch (e) {
      debugPrint('SubscriptionService: restore failed ($e)');
      lastError.value = 'Could not restore your purchases.';
    }
  }

  void dispose() {
    _sub?.cancel();
    _entitlements.close();
    state.dispose();
    price.dispose();
    lastError.dispose();
    _http.close();
  }

  // ── Purchase handling ──────────────────────────────────────────────────

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // A UPI mandate can sit here for a long time. Say so rather than
          // spinning forever or, worse, treating it as a failure.
          state.value = SubscriptionState.pending;

        case PurchaseStatus.error:
          debugPrint('SubscriptionService: ${purchase.error}');
          lastError.value = 'The payment did not go through.';
          state.value = SubscriptionState.available;

        case PurchaseStatus.canceled:
          lastError.value = null;
          state.value = SubscriptionState.available;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final granted = await _verify(purchase);
          state.value = granted
              ? SubscriptionState.subscribed
              : SubscriptionState.available;
          if (!granted) {
            lastError.value =
                'We could not confirm your subscription. If you were charged, '
                'try Restore Purchases in a moment.';
          }
          _entitlements.add(granted);
      }

      // Must happen for every purchase Play hands us, including errors —
      // Play re-delivers anything left incomplete on the next launch, and on
      // Android an unacknowledged purchase is automatically refunded after
      // three days.
      if (purchase.pendingCompletePurchase) {
        try {
          await _billing.completePurchase(purchase);
        } catch (e) {
          debugPrint('SubscriptionService: completePurchase failed ($e)');
        }
      }
    }
  }

  /// Asks the backend whether Google agrees this purchase is real and active.
  Future<bool> _verify(PurchaseDetails purchase) async {
    final url = _verifyUrl;
    if (url == null) {
      // No server to ask. Refusing here rather than trusting the client keeps
      // one rule intact: entitlement is never decided on the device.
      debugPrint('SubscriptionService: no backend, cannot verify');
      return false;
    }

    try {
      final response = await _http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-voix-app-token': BackendConfig.appToken,
            },
            body: jsonEncode({
              'userId': userId,
              'productId': purchase.productID,
              // On Android this is the Play purchase token.
              'purchaseToken': purchase.verificationData.serverVerificationData,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('SubscriptionService: verify ${response.statusCode} '
            '${response.body}');
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['premium'] == true;
    } catch (e) {
      debugPrint('SubscriptionService: verify failed ($e)');
      return false;
    }
  }
}
