import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:voix/data/services/subscription_service.dart';

/// The failure that matters here is someone paying and not getting what they
/// paid for. These tests hold the two rules that prevent it: every purchase is
/// completed with Play whatever happens to it, and entitlement is only ever
/// granted on the server's word.
void main() {
  late _FakeBilling billing;

  setUp(() => billing = _FakeBilling());

  /// Builds the service and runs init(), which is what attaches the purchase
  /// stream listener everything below depends on.
  Future<SubscriptionService> serviceWith({required http.Client client}) async {
    final service = SubscriptionService(
      billing: billing,
      httpClient: client,
      verifyEndpoint: Uri.parse('https://test.invalid/v1/verify'),
    );
    await service.init(userId: 'u1');
    return service;
  }

  http.Client verifierReturning(Object body, {int status = 200}) =>
      MockClient((_) async => http.Response(jsonEncode(body), status));

  PurchaseDetails purchase(PurchaseStatus status, {bool pendingComplete = true}) {
    return PurchaseDetails(
      productID: SubscriptionService.productId,
      purchaseID: 'p1',
      status: status,
      transactionDate: '0',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'play-purchase-token',
        source: 'google_play',
      ),
    )..pendingCompletePurchase = pendingComplete;
  }

  group('entitlement is the server\'s decision', () {
    test('grants premium when the backend confirms it', () async {
      final service = await serviceWith(
        client: verifierReturning({'premium': true}),
      );
      addTearDown(service.dispose);

      final granted = service.entitlements.first;
      billing.emit([purchase(PurchaseStatus.purchased)]);

      expect(await granted, isTrue);
      expect(service.state.value, SubscriptionState.subscribed);
    });

    test('refuses premium when the backend says no', () async {
      // The purchase looked fine to Play, but Google told our server the token
      // is not an active subscription. The server wins.
      final service = await serviceWith(
        client: verifierReturning({'premium': false}),
      );
      addTearDown(service.dispose);

      final granted = service.entitlements.first;
      billing.emit([purchase(PurchaseStatus.purchased)]);

      expect(await granted, isFalse);
      expect(service.state.value, isNot(SubscriptionState.subscribed));
      expect(service.lastError.value, isNotNull);
    });

    test('refuses premium when the backend is unreachable', () async {
      final service = await serviceWith(
        client: MockClient((_) async => throw const _Unreachable()),
      );
      addTearDown(service.dispose);

      final granted = service.entitlements.first;
      billing.emit([purchase(PurchaseStatus.purchased)]);

      // Failing closed is deliberate: an outage must not become a way to get
      // a per-minute-billed feature for free.
      expect(await granted, isFalse);
    });

    test('a restored purchase is verified too, not trusted', () async {
      final service = await serviceWith(
        client: verifierReturning({'premium': true}),
      );
      addTearDown(service.dispose);

      final granted = service.entitlements.first;
      billing.emit([purchase(PurchaseStatus.restored)]);

      expect(await granted, isTrue);
      expect(billing.verifiedTokens, isEmpty); // nothing granted by Play alone
    });
  });

  group('purchases are always completed with Play', () {
    test('completes a successful purchase', () async {
      final service = await serviceWith(
        client: verifierReturning({'premium': true}),
      );
      addTearDown(service.dispose);

      final granted = service.entitlements.first;
      billing.emit([purchase(PurchaseStatus.purchased)]);
      await granted;

      expect(billing.completed, hasLength(1));
    });

    test('completes a purchase the server rejected', () async {
      // An unacknowledged Android purchase is auto-refunded after three days.
      // Leaving it incomplete because verification failed would quietly undo
      // the sale.
      final service = await serviceWith(
        client: verifierReturning({'premium': false}),
      );
      addTearDown(service.dispose);

      final granted = service.entitlements.first;
      billing.emit([purchase(PurchaseStatus.purchased)]);
      await granted;

      expect(billing.completed, hasLength(1));
    });

    test('completes an errored purchase', () async {
      final service = await serviceWith(client: verifierReturning({}));
      addTearDown(service.dispose);

      billing.emit([purchase(PurchaseStatus.error)]);
      await Future<void>.delayed(Duration.zero);

      expect(billing.completed, hasLength(1));
      expect(service.lastError.value, isNotNull);
    });

    test('does not re-complete a purchase Play already settled', () async {
      final service = await serviceWith(client: verifierReturning({}));
      addTearDown(service.dispose);

      billing.emit([
        purchase(PurchaseStatus.canceled, pendingComplete: false),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(billing.completed, isEmpty);
    });
  });

  group('pending payments', () {
    test('a pending purchase is reported, not treated as a failure', () async {
      // UPI mandates can sit pending for minutes. Showing an error here would
      // send someone who is about to pay to a competitor.
      final service = await serviceWith(client: verifierReturning({}));
      addTearDown(service.dispose);

      billing.emit([purchase(PurchaseStatus.pending)]);
      await Future<void>.delayed(Duration.zero);

      expect(service.state.value, SubscriptionState.pending);
      expect(service.lastError.value, isNull);
    });
  });
}

/// A stand-in for Play that lets a test push purchases through the stream.
class _FakeBilling implements InAppPurchase {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  final verifiedTokens = <String>[];

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: const [], notFoundIDs: ids.toList());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unreachable implements Exception {
  const _Unreachable();
}
