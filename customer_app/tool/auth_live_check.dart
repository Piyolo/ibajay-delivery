// Live check of AuthApiService against the running backend.
// Run:  dart run tool/auth_live_check.dart
//
// Uses the seeded vendor-owner dev account (password "vendor123").
// Skips the real OTP flows — those were verified over HTTP separately
// (Resend sandbox only delivers to the account owner's address).
import 'dart:developer' as dev;

import 'package:ibajay_eats/services/api_client.dart';
import 'package:ibajay_eats/services/auth_api_service.dart';

Future<void> main() async {
  final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
  final service = AuthApiService(client);
  const mobile = '+639900000069';

  // 1. Login
  final tokens = await service.login(mobileNumber: mobile, password: 'vendor123');
  _check('login returns tokens', tokens.accessToken.isNotEmpty && tokens.refreshToken.isNotEmpty);

  // 2. Profile via /auth/me with the Bearer token attached
  client.authToken = tokens.accessToken;
  final me = await service.me();
  _check('me() returns the profile', me['email'] == 'owner.aling.nenas.carinderia@ibajayeats.dev');
  _check('me() has a UUID id', (me['id'] as String).length == 36);

  // 3. Token refresh round-trip
  final refreshed = await service.refresh(tokens.refreshToken);
  _check('refresh returns new tokens', refreshed.accessToken.isNotEmpty);
  client.authToken = refreshed.accessToken;
  await service.me();
  _check('me() works with refreshed token', true);

  // 4. Bad password -> AuthException with the backend's message
  try {
    await service.login(mobileNumber: mobile, password: 'wrong-password');
    _check('bad login rejected', false);
  } on AuthException catch (e) {
    _check('bad login rejected', e.isUnauthorized && e.message.contains('Invalid'));
  }

  // 5. Duplicate registration -> 409 surfaced as AuthException
  try {
    await service.registerStart(
      fullName: 'Dup',
      mobileNumber: '+639900000999',
      email: 'owner.aling.nenas.carinderia@ibajayeats.dev',
    );
    _check('duplicate registration rejected', false);
  } on AuthException catch (e) {
    _check('duplicate registration rejected', e.message.contains('already exists'));
  }

  client.dispose();
  dev.log('ALL AUTH CHECKS PASSED');
}

void _check(String label, bool ok) {
  dev.log('${ok ? "PASS" : "FAIL"}: $label');
  if (!ok) throw StateError(label);
}
