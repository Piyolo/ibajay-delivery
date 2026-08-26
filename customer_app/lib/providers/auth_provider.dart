import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_api_service.dart';
import '../services/preferences_service.dart';

enum AuthStatus { signedOut, signedIn }

enum _PendingFlow { registration, passwordReset }

/// Real auth against `/api/v1/auth/*`: email-OTP registration, login by
/// mobile + password, JWT session with refresh, forgot-password, and
/// password change.
///
/// JWTs persist via [PreferencesService]; on session restore the access
/// token is validated against `/auth/me` (refreshing it once if expired).
/// If the backend is unreachable, the cached profile keeps the session
/// alive so the app still works offline.
///
/// Profile edits and email change remain local-only for now — the backend
/// has no user-profile update endpoints yet (next slice).
class AuthProvider extends ChangeNotifier {
  factory AuthProvider({ApiClient? apiClient, AuthApiService? apiService}) {
    final client = apiClient ?? ApiClient();
    return AuthProvider._(client, apiService ?? AuthApiService(client));
  }

  AuthProvider._(this._client, this.api);

  final ApiClient _client;
  final AuthApiService api;

  /// The shared client — its auth token is kept fresh, so other providers
  /// (chat) reuse it instead of unauthenticated instances.
  ApiClient get client => _client;

  AuthStatus status = AuthStatus.signedOut;
  AppUser? currentUser;

  /// Backend error message from the last failed auth attempt (login,
  /// registration, OTP...). Cleared on the next attempt. Screens show
  /// this instead of a generic string when set.
  String? lastAuthError;

  bool get hasSavedLocation => _hasSavedLocation;
  bool _hasSavedLocation = false;  // In-flight registration / reset state (shared by the OTP + password steps)
  String? _pendingEmail;
  _PendingFlow _pendingFlow = _PendingFlow.registration;

  /// Restores any previously saved session. Call once at app start
  /// (splash) before routing.
  Future<void> restoreSession() async {
    final access = await PreferencesService.getString(PreferencesService.kAccessToken);
    final refresh = await PreferencesService.getString(PreferencesService.kRefreshToken);
    final sessionJson = await PreferencesService.getString(PreferencesService.kSessionUser);

    if (sessionJson != null) {
      try {
        currentUser = AppUser.fromJson(jsonDecode(sessionJson) as Map<String, dynamic>);
      } catch (_) {
        currentUser = null;
      }
    }

    if (access == null || access.isEmpty) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _client.authToken = access;
    status = AuthStatus.signedIn;

    // Per-user flag: whether THIS account already saved a location. Read
    // only after the cached profile gives us the user id.
    if (currentUser?.id.isNotEmpty == true) {
      _hasSavedLocation = await PreferencesService.getBool(
          PreferencesService.kHasSavedLocationFor(currentUser!.id));
    }

    // Validate the token and refresh the profile; a stale access token is
    // refreshed once. Network failures (including free-tier server cold
    // starts) keep the cached session — we never log someone out just
    // because the server was slow to wake.
    try {
      currentUser = await _fetchMeWithRefresh(access, refresh);
      if (currentUser?.id.isNotEmpty == true) {
        _hasSavedLocation = await PreferencesService.getBool(
            PreferencesService.kHasSavedLocationFor(currentUser!.id));
      }
    } on AuthException {
      // Invalid/expired beyond refresh — force re-login.
      currentUser = null;
      status = AuthStatus.signedOut;
      _client.authToken = null;
      await _clearTokens();
    } catch (_) {
      // Offline / timed out: keep the cached profile and session.
    }
    notifyListeners();
  }

  // ---- Registration (Steps 1-4) ----

  /// Step 1: sends the OTP to [email] via the backend. Returns '' (the
  /// code arrives by email — no demo value anymore).
  Future<String> startRegistration({
    required String fullName,
    required String mobileNumber,
    required String email,
  }) async {
    lastAuthError = null;
    _pendingEmail = email;
    _pendingFlow = _PendingFlow.registration;
    try {
      await api.registerStart(fullName: fullName, mobileNumber: mobileNumber, email: email);
    } on AuthException catch (e) {
      lastAuthError = e.message;
    }
    return '';
  }

  /// Steps 2-3: verify the emailed OTP. For the password-reset flow the
  /// code is validated server-side at reset time, so this returns true
  /// without a server round-trip.
  Future<bool> verifyOtp(String code) async {
    lastAuthError = null;
    if (_pendingFlow == _PendingFlow.passwordReset) return true;
    try {
      await api.verifyRegistrationOtp(email: _pendingEmail ?? '', otpCode: code);
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    }
  }

  /// Re-sends the OTP for whichever flow is pending.
  Future<String> resendOtp() async {
    lastAuthError = null;
    try {
      if (_pendingFlow == _PendingFlow.passwordReset) {
        await api.forgotPasswordStart(_pendingEmail ?? '');
      } else {
        // register/start re-issues a fresh OTP for the same details.
        await api.registerStart(
          fullName: currentUser?.fullName ?? 'Customer',
          mobileNumber: currentUser?.mobileNumber ?? '',
          email: _pendingEmail ?? '',
        );
      }
    } on AuthException catch (e) {
      lastAuthError = e.message;
    }
    return '';
  }

  /// Step 4: creates the account and signs in.
  Future<void> completeRegistration(String password) async {
    lastAuthError = null;
    final tokens = await api.setPassword(email: _pendingEmail ?? '', password: password);
    await _establishSession(tokens);
  }

  Future<bool> login({required String mobileNumber, required String password}) async {
    lastAuthError = null;
    try {
      final tokens = await api.login(mobileNumber: mobileNumber, password: password);
      await _establishSession(tokens);
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    }
  }

  // ---- Forgot password ----

  Future<String> requestPasswordReset(String email) async {
    lastAuthError = null;
    _pendingEmail = email;
    _pendingFlow = _PendingFlow.passwordReset;
    try {
      await api.forgotPasswordStart(email);
    } on AuthException catch (e) {
      lastAuthError = e.message;
    }
    return '';
  }

  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    lastAuthError = null;
    try {
      await api.resetPassword(email: email, otpCode: otp, newPassword: newPassword);
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    }
  }

  // ---- Settings ----

  /// Real credential check (login round-trip). Returns true when valid.
  Future<bool> verifyPassword(String password) async {
    final mobile = currentUser?.mobileNumber;
    if (mobile == null || mobile.isEmpty) return false;
    final error = await api.checkCurrentPassword(
      mobileNumber: mobile,
      currentPassword: password,
    );
    return error == null;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.changePassword(currentPassword: currentPassword, newPassword: newPassword);
  }

  // ---- Email change (OTP-confirmed, local-only until the backend gains
  // a profile-update endpoint) ----

  String? _pendingNewEmail;
  String _emailChangeOtp = '';

  Future<String> startEmailChange(String newEmail) async {
    final email = newEmail.trim();
    if (currentUser != null && email.toLowerCase() == currentUser!.email.toLowerCase()) {
      throw Exception('same_email');
    }
    _pendingNewEmail = email;
    _emailChangeOtp = '123456'; // local demo code — no backend endpoint yet
    return _emailChangeOtp;
  }

  String? get pendingNewEmail => _pendingNewEmail;

  Future<bool> confirmEmailChange(String code) async {
    if (_pendingNewEmail == null) return false;
    if (code != _emailChangeOtp) return false;

    currentUser!.email = _pendingNewEmail!;
    _pendingNewEmail = null;
    await _persistSession();
    notifyListeners();
    return true;
  }

  void cancelEmailChange() {
    _pendingNewEmail = null;
  }

  /// Profile edits from the Settings screen. Local-only until the backend
  /// gains a profile-update endpoint (persisted to the cached session).
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? mobileNumber,
  }) async {
    if (currentUser == null) return;
    if (fullName != null && fullName.trim().isNotEmpty) currentUser!.fullName = fullName.trim();
    if (email != null && email.trim().isNotEmpty) currentUser!.email = email.trim();
    if (mobileNumber != null && mobileNumber.trim().isNotEmpty) {
      currentUser!.mobileNumber = mobileNumber.trim();
    }
    await _persistSession();
    notifyListeners();
  }

  bool get hasRegisteredAccount => currentUser != null;

  void markLocationSaved() {
    _hasSavedLocation = true;
    final uid = currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      PreferencesService.setBool(PreferencesService.kHasSavedLocationFor(uid), true);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    currentUser = null;
    status = AuthStatus.signedOut;
    _hasSavedLocation = false;
    _client.authToken = null;
    await _clearTokens();
    await PreferencesService.remove(PreferencesService.kSessionUser);
    // NOTE: per-user data (addresses, favorites, flags) intentionally stays
    // on disk under its own keys — signing back in restores it.
    notifyListeners();
  }

  // ---- Internals ----

  /// Stores tokens, loads the profile, and marks the session signed in.
  Future<void> _establishSession(AuthTokens tokens) async {
    await PreferencesService.setString(PreferencesService.kAccessToken, tokens.accessToken);
    await PreferencesService.setString(PreferencesService.kRefreshToken, tokens.refreshToken);
    _client.authToken = tokens.accessToken;

    final me = await api.me();
    currentUser = AppUser(
      id: me['id'] as String? ?? '',
      fullName: me['full_name'] as String? ?? '',
      mobileNumber: me['mobile_number'] as String? ?? '',
      email: me['email'] as String? ?? '',
    );
    status = AuthStatus.signedIn;
    await _persistSession();
    notifyListeners();
  }

  /// GET /auth/me with a single transparent refresh on an expired token.
  Future<AppUser?> _fetchMeWithRefresh(String access, String? refresh) async {
    try {
      final me = await api.me();
      return _userFromMe(me);
    } on AuthException catch (e) {
      final unauthorized = e.isUnauthorized || e.message.contains('credentials');
      if (!unauthorized || refresh == null || refresh.isEmpty) rethrow;
      final tokens = await api.refresh(refresh);
      await PreferencesService.setString(PreferencesService.kAccessToken, tokens.accessToken);
      await PreferencesService.setString(PreferencesService.kRefreshToken, tokens.refreshToken);
      _client.authToken = tokens.accessToken;
      final me = await api.me();
      return _userFromMe(me);
    }
  }

  AppUser? _userFromMe(Map<String, dynamic> me) => AppUser(
        id: me['id'] as String? ?? '',
        fullName: me['full_name'] as String? ?? '',
        mobileNumber: me['mobile_number'] as String? ?? '',
        email: me['email'] as String? ?? '',
      );

  Future<void> _persistSession() async {
    if (currentUser == null) return;
    await PreferencesService.setString(
        PreferencesService.kSessionUser, jsonEncode(currentUser!.toJson()));
  }

  Future<void> _clearTokens() async {
    await PreferencesService.remove(PreferencesService.kAccessToken);
    await PreferencesService.remove(PreferencesService.kRefreshToken);
  }
}
