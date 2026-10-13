import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer for [raw] (a customer mobile straight from the
/// API, e.g. `order.customer_mobile`). Never throws — every failure path
/// surfaces as a snackbar so calling a customer can't crash a screen.
Future<void> callCustomer(BuildContext context, String? raw) async {
  final messenger = ScaffoldMessenger.of(context);
  final phone = raw?.replaceAll(RegExp(r'[^\d+]'), '') ?? '';
  if (phone.isEmpty) {
    messenger.showSnackBar(const SnackBar(
        content: Text('No phone number available for this customer')));
    return;
  }

  final uri = Uri(scheme: 'tel', path: phone);
  try {
    var launched = false;
    if (await canLaunchUrl(uri)) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!launched) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not open the phone dialer on this device')));
    }
  } catch (_) {
    messenger
        .showSnackBar(const SnackBar(content: Text('Could not open the phone dialer')));
  }
}
