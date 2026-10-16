import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ibajay_eats_vendor/models/order.dart';
import 'package:ibajay_eats_vendor/providers/order_provider.dart';
import 'package:ibajay_eats_vendor/services/api_client.dart';

const _inboxJson = '[{'
    '"id":"o-1",'
    '"order_number":"ORD-1",'
    '"created_at":"2026-10-16T10:00:00Z",'
    '"status":"pending",'
    '"delivery_method":"delivery",'
    '"items":[]'
    '}]';

OrderProvider _provider(MockClient client) => OrderProvider(
    apiClient: ApiClient(client: client, baseUrl: 'http://localhost'));

void main() {
  group('OrderProvider action guards', () {
    test('acceptOrder is not sent twice while the first call is in flight',
        () async {
      var statusCalls = 0;
      final gate = Completer<void>();
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response(_inboxJson, 200);
        if (request.method == 'PATCH') {
          statusCalls++;
          await gate.future;
          return http.Response('{"id":"o-1","status":"accepted"}', 200);
        }
        return http.Response('{"detail":"not found"}', 404);
      });
      final provider = _provider(client);
      await provider.load();
      expect(provider.findById('o-1'), isNotNull);

      final first = provider.acceptOrder('o-1');
      expect(provider.isBusy('o-1'), isTrue);
      final second = provider.acceptOrder('o-1');
      expect(await second, isFalse);

      gate.complete();
      expect(await first, isTrue);
      expect(statusCalls, 1);
      expect(provider.findById('o-1')!.status, OrderStatus.accepted);
      expect(provider.isBusy('o-1'), isFalse);
      expect(provider.lastError, isNull);
    });

    test('rejectOrder sends the chosen reason to the cancel endpoint', () async {
      String? seenReason;
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response(_inboxJson, 200);
        if (request.method == 'POST') {
          seenReason = request.url.queryParameters['reason'];
          return http.Response('{"id":"o-1","status":"cancelled"}', 200);
        }
        return http.Response('{"detail":"not found"}', 404);
      });
      final provider = _provider(client);
      await provider.load();

      final ok = await provider.rejectOrder('o-1', reason: 'Out of stock');
      expect(ok, isTrue);
      expect(seenReason, 'Out of stock');
      expect(provider.findById('o-1')!.status, OrderStatus.cancelled);
      expect(provider.isBusy('o-1'), isFalse);
    });

    test('rejectOrder failure surfaces lastError and keeps the order pending',
        () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response(_inboxJson, 200);
        if (request.method == 'POST') {
          return http.Response('{"detail":"Order already delivered"}', 409);
        }
        return http.Response('{"detail":"not found"}', 404);
      });
      final provider = _provider(client);
      await provider.load();

      final ok = await provider.rejectOrder('o-1', reason: 'Too busy right now');
      expect(ok, isFalse);
      expect(provider.lastError, 'Order already delivered');
      expect(provider.findById('o-1')!.status, OrderStatus.pending);
      expect(provider.isBusy('o-1'), isFalse);
    });

    test('failed status advance rolls back and reports lastError', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') return http.Response(_inboxJson, 200);
        if (request.method == 'PATCH') {
          return http.Response('{"detail":"Invalid status transition"}', 400);
        }
        return http.Response('{"detail":"not found"}', 404);
      });
      final provider = _provider(client);
      await provider.load();

      final ok = await provider.acceptOrder('o-1');
      expect(ok, isFalse);
      expect(provider.findById('o-1')!.status, OrderStatus.pending);
      expect(provider.lastError, 'Invalid status transition');
      expect(provider.isBusy('o-1'), isFalse);
    });
  });
}
