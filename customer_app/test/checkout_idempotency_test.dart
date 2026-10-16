import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ibajay_eats/models/cart.dart';
import 'package:ibajay_eats/models/order.dart';
import 'package:ibajay_eats/models/vendor.dart';
import 'package:ibajay_eats/providers/order_provider.dart';
import 'package:ibajay_eats/services/api_client.dart';

/// Checkout idempotency semantics:
///  - A failed attempt (timeout/network error paths in real life) keeps its
///    key, so the RETRY carries the SAME key and the backend replays the
///    original order instead of creating a second paid order.
///  - After a SUCCESSFUL checkout the key resets (next order = new session).
///  - An edited cart gets a fresh key (replaying a stale order would be wrong).
///  - The cancel action ignores double-taps.
void main() {
  FoodItemRef food(String id) =>
      FoodItemRef(id: id, vendorId: 'vendor-1', name: 'Adobo', price: 95);

  VendorProfile vendor() => VendorProfile(
        id: 'vendor-1',
        storeName: 'Test Store',
        address: 'Test address',
        latitude: 11.8,
        longitude: 122.2,
      );

  Cart cart(String itemId) => Cart()
    ..vendorId = 'vendor-1'
    ..vendorName = 'Test Store'
    ..items.add(CartItem(id: 'ci_1', foodItem: food(itemId), quantity: 2));

  Future<CustomerOrder> checkoutCall(
    OrderProvider provider, {
    required String itemId,
  }) =>
      provider.checkout(
        cart: cart(itemId),
        vendor: vendor(),
        fulfillmentType: FulfillmentType.delivery,
        paymentMethod: PaymentMethod.cashOnDelivery,
        addressId: 'addr-1',
      );

  final orderJson = {
    'id': 'ord-1',
    'order_number': 'ORD-20261016-AAAAAA',
    'vendor_id': 'vendor-1',
    'status': 'pending',
    'delivery_method': 'delivery',
    'payment_method': 'cash_on_delivery',
    'subtotal': 190.0,
    'delivery_fee': 30.0,
    'discount': 0,
    'total': 220.0,
    'created_at': '2026-10-16T10:00:00Z',
    'items': [
      {
        'item_name': 'Adobo',
        'quantity': 2,
        'unit_price': 95.0,
        'selected_options': {},
        'line_total': 190.0,
        'special_instructions': '',
      }
    ],
  };

  testWidgets('failed attempt keeps its key; success resets it', (tester) async {
    final keys = <String>[];
    var failNext = true;

    final mock = MockClient((request) async {
      keys.add(request.headers['Idempotency-Key'] ?? 'MISSING');
      if (failNext) {
        return http.Response('{"detail": "boom"}', 500);
      }
      return http.Response(jsonEncode(orderJson), 201,
          headers: {'content-type': 'application/json'});
    });

    final provider =
        OrderProvider(apiClient: ApiClient(client: mock, baseUrl: 'https://test.local'));

    // First attempt fails server-side.
    await expectLater(
      checkoutCall(provider, itemId: 'food-1'),
      throwsA(isA<ApiException>()),
    );
    expect(keys, hasLength(1));
    expect(keys[0], matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));

    // Retry with the SAME cart: the SAME key must go out (replay path).
    failNext = false;
    await checkoutCall(provider, itemId: 'food-1');
    expect(keys, hasLength(2));
    expect(keys[1], keys[0], reason: 'retry after failure reuses the key');

    // A NEW checkout after success is a new session: fresh key.
    await checkoutCall(provider, itemId: 'food-1');
    expect(keys, hasLength(3));
    expect(keys[2], isNot(equals(keys[0])), reason: 'success resets the key');
  });

  test('an edited cart gets a fresh key even mid-session', () async {
    final keys = <String>[];

    final mock = MockClient((request) async {
      keys.add(request.headers['Idempotency-Key'] ?? 'MISSING');
      return http.Response(jsonEncode(orderJson), 201,
          headers: {'content-type': 'application/json'});
    });

    final provider =
        OrderProvider(apiClient: ApiClient(client: mock, baseUrl: 'https://test.local'));

    await checkoutCall(provider, itemId: 'food-1');
    await checkoutCall(provider, itemId: 'food-2'); // different cart content

    expect(keys, hasLength(2));
    expect(keys[0], isNot(equals(keys[1])),
        reason: 'changed cart must not reuse the previous order\'s key');
  });

  test('double-tapped cancel fires the backend once', () async {
    final cancelCalls = <String>[];
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/cancel')) {
        cancelCalls.add(request.url.toString());
        // Small latency window to let the second tap race the first.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{"ok": true}', 200);
      }
      return http.Response('{"detail": "not found"}', 404);
    });

    final provider =
        OrderProvider(apiClient: ApiClient(client: mock, baseUrl: 'https://test.local'));

    // Two taps racing: only the first may reach the backend.
    final results = await Future.wait([
      provider.cancelOrder('ord-1', 'Changed my mind'),
      provider.cancelOrder('ord-1', 'Changed my mind'),
    ]).catchError((_) => <bool>[]);

    expect(cancelCalls, hasLength(1));
    expect(results.where((r) => r == true), hasLength(1));
  });
}
