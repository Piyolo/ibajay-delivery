// Live check of the deployed vendor portal.
// Run:  dart run tool/vendor_live_check.dart
import 'dart:io';

import 'package:ibajay_eats_vendor/services/api_client.dart';
import 'package:ibajay_eats_vendor/services/vendor_api_service.dart';

Future<void> main() async {
  final client = ApiClient(baseUrl: 'https://ibajay-delivery.onrender.com');
  final login = await client.post('/auth/login', body: {
    'mobile_number': '+639900000069',
    'password': 'vendor123',
  }) as Map<String, dynamic>;
  client.authToken = login['access_token'] as String;
  _check('login', true);

  final api = VendorApiService(client);
  final me = await api.getStore();
  _check('store profile: ${me['store_name']}', me['id'] != null);
  final barangays = (me['delivery']['delivery_barangays'] as List).join(', ');
  _check('delivery barangays: $barangays', barangays.isNotEmpty);

  final menu = await api.getMenu();
  _check('menu: ${menu.length} items', menu.isNotEmpty);

  final analytics = await api.getAnalytics();
  _check('analytics: ${(analytics['week'] as List).length}-day chart data', true);

  final inbox = await api.getInbox();
  _check('order inbox: ${inbox.length} orders', inbox is List);

  client.dispose();
  stdout.writeln('ALL VENDOR PORTAL CHECKS PASSED');
}

void _check(String label, bool ok) {
  stdout.writeln('${ok ? "PASS" : "FAIL"}: $label');
  if (!ok) throw StateError(label);
}
