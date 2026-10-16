import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:ibajay_eats/providers/order_provider.dart';
import 'package:ibajay_eats/screens/orders/order_history_screen.dart';
import 'package:ibajay_eats/services/api_client.dart';

/// Cancel affordance in the ACTIVE order list: pending/accepted cards
/// carry a Cancel Order button (the only states the backend's cancel
/// policy allows); anything later in the flow must not show one. The
/// confirm dialog + reason flow mirrors order_tracking_screen.
void main() {
  Map<String, dynamic> orderJson({required String id, required String status}) => {
        'id': id,
        'order_number': 'ORD-20261016-$id',
        'vendor_id': 'vendor-1',
        'status': status,
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

  testWidgets('only pending/accepted orders offer Cancel; flow hits the API with a reason',
      (tester) async {
    final cancelCalls = <Uri>[];
    // After a cancel succeeds the provider re-pulls the list — the mock
    // must reflect the server-side status flip or the refresh would
    // resurrect the old state.
    final cancelled = <String>{};
    Map<String, dynamic> row(String id, String status) =>
        orderJson(id: id, status: cancelled.contains(id) ? 'cancelled' : status);
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST' && path.endsWith('/cancel')) {
        cancelCalls.add(request.url);
        // Path shape: /api/v1/orders/{id}/cancel
        final segments = path.split('/');
        cancelled.add(segments[segments.length - 2]);
        return http.Response(jsonEncode(row(segments[segments.length - 2], 'cancelled')), 200,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/orders/my-orders')) {
        // One cancellable (pending) and one not (preparing) — both land
        // on the Active tab.
        return http.Response(
          jsonEncode([row('ord-1', 'pending'), row('ord-2', 'preparing')]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "not found"}', 404);
    });

    final apiClient = ApiClient(client: mock, baseUrl: 'https://test.local')
      ..authToken = 'test-token';
    final provider = OrderProvider(apiClient: apiClient);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: provider,
        child: const MaterialApp(home: OrderHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Active tab: pending has a Cancel button, preparing does not.
    expect(find.text('Cancel Order'), findsOneWidget);
    expect(provider.byId('ord-1')!.status.toString(), contains('pending'));

    // Confirm-style prompt, then the cancel call with a reason.
    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel Order'));
    await tester.pumpAndSettle();

    expect(cancelCalls, hasLength(1));
    expect(cancelCalls.single.path, contains('/orders/ord-1/cancel'));
    expect(cancelCalls.single.queryParameters['reason'], isNotEmpty);
    expect(find.text('Your order was cancelled'), findsOneWidget);
    expect(provider.byId('ord-1')!.status.toString(), contains('cancelled'));
  });

  testWidgets('a policy refusal surfaces the backend message verbatim',
      (tester) async {
    const refusal =
        'This order can no longer be cancelled — it is already being prepared.';
    final mock = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST' && path.endsWith('/cancel')) {
        return http.Response(jsonEncode({'detail': refusal}), 409,
            headers: {'content-type': 'application/json'});
      }
      if (path.endsWith('/orders/my-orders')) {
        return http.Response(
          jsonEncode([orderJson(id: 'ord-1', status: 'pending')]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{"detail": "not found"}', 404);
    });

    final apiClient = ApiClient(client: mock, baseUrl: 'https://test.local')
      ..authToken = 'test-token';
    final provider = OrderProvider(apiClient: apiClient);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: provider,
        child: const MaterialApp(home: OrderHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel Order'));
    await tester.pumpAndSettle();

    expect(find.text(refusal), findsOneWidget);
    expect(provider.byId('ord-1')!.status.toString(), contains('pending'),
        reason: 'a refused cancel must not flip the local status');
  });
}
