import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/auth_api_service.dart';
import '../services/preferences_service.dart';
import '../services/vendor_api_service.dart';

/// Real store management against /vendor/me + /auth/*.
///
/// Login is by mobile number + password with a vendor-role account. New
/// vendors register (email OTP), set a password, then create their store.
/// Everything persists server-side; a local cache keeps the last known
/// state for offline viewing.
class VendorProvider extends ChangeNotifier {
  /// All services must share ONE ApiClient — the auth token is set on the
  /// client instance, so separate instances would send unauthenticated
  /// requests.
  factory VendorProvider({ApiClient? apiClient}) {
    final client = apiClient ?? ApiClient();
    return VendorProvider._(
      client,
      VendorApiService(client),
      AuthApiService(client),
    );
  }

  VendorProvider._(this._client, this.api, this._auth) {
    _vendor = VendorProfile(
      id: '',
      ownerName: '',
      storeName: '',
      mobileNumber: '',
      email: '',
    );
  }

  final ApiClient _client;
  final VendorApiService api;
  final AuthApiService _auth;

  late VendorProfile _vendor;
  bool _isAuthenticated = false;
  bool _hasCompletedStoreSetup = false;
  bool _restored = false;
  String? _mobileNumber;
  String? lastAuthError;
  bool _isBusy = false;

  // In-flight registration state (register form -> OTP -> password -> setup)
  String? _pendingEmail;
  String? _pendingOwnerName;
  String? _pendingMobile;
  String? _pendingStoreName;
  String? _pendingStoreDescription;

  VendorProfile get vendor => _vendor;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasCompletedStoreSetup => _hasCompletedStoreSetup;
  bool get restored => _restored;
  bool get isBusy => _isBusy;

  /// Store details collected during registration, shown prefilled in the
  /// store setup flow.
  String get pendingStoreName => _pendingStoreName ?? '';
  String get pendingStoreDescription => _pendingStoreDescription ?? '';
  String get pendingOwnerName => _pendingOwnerName ?? '';

  /// Restores the persisted session: validates the stored access token
  /// against /vendor/me (refreshing once if expired) and reloads the live
  /// store profile. Falls back to the cached profile when offline.
  Future<void> restoreSession() async {
    final access = await PreferencesService.getString(PreferencesService.kAccessToken);
    final refresh = await PreferencesService.getString(PreferencesService.kRefreshToken);
    final profileJson = await PreferencesService.getString(PreferencesService.kProfile);
    final setupDone = await PreferencesService.getBool(PreferencesService.kSetupDone);
    final mobile = await PreferencesService.getString(PreferencesService.kOwnerMobile);

    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        _vendor = VendorProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
      } catch (_) {
        _vendor = VendorProfile(
          id: '',
          ownerName: '',
          storeName: '',
          mobileNumber: '',
          email: '',
        );
      }
    }

    if (access == null || access.isEmpty) {
      _isAuthenticated = false;
      _restored = true;
      notifyListeners();
      return;
    }

    _mobileNumber = mobile;
    _client.authToken = access;
    _isAuthenticated = true;
    _hasCompletedStoreSetup = setupDone;

    try {
      await _loadStore();
    } on StoreApiException catch (e) {
      if (e.statusCode == 404) {
        // Signed in but the store hasn't been created yet — route through
        // the setup flow.
        _hasCompletedStoreSetup = false;
      } else if (e.isUnauthorized && refresh != null && refresh.isNotEmpty) {
        try {
          final tokens = await _auth.refresh(refresh);
          await _saveTokens(tokens);
          await _loadStore();
        } on AuthException {
          await _forceSignOut();
        } catch (_) {
          // Offline — keep cached profile.
        }
      }
      // Other errors (offline): keep cached profile.
    } catch (_) {
      // Offline — keep cached profile.
    }

    _restored = true;
    notifyListeners();
  }

  Future<void> _loadStore() async {
    final json = await api.getStore();
    _vendor = VendorProfile.fromApi(json);
    _hasCompletedStoreSetup = true;
    await PreferencesService.setBool(PreferencesService.kSetupDone, true);
    await _persistVendor();
  }

  /// Real login: POST /auth/login, requires the `vendor` role, then loads
  /// the store profile. Returns false and sets [lastAuthError] on failure.
  Future<bool> signIn({required String mobileNumber, required String password}) async {
    lastAuthError = null;
    _isBusy = true;
    notifyListeners();
    try {
      final tokens = await _auth.login(mobileNumber: mobileNumber, password: password);
      await _saveTokens(tokens);
      _client.authToken = tokens.accessToken;

      final me = await _auth.me();
      if (me['role'] != 'vendor') {
        await _forceSignOut();
        lastAuthError = 'This account is not a vendor account.';
        return false;
      }

      _mobileNumber = mobileNumber;
      await PreferencesService.setString(PreferencesService.kOwnerMobile, mobileNumber);
      await _loadStore();
      _isAuthenticated = true;
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    } on StoreApiException catch (e) {
      lastAuthError = e.message;
      await _forceSignOut();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _forceSignOut();
    notifyListeners();
  }

  Future<void> _forceSignOut() async {
    _isAuthenticated = false;
    _hasCompletedStoreSetup = false;
    _client.authToken = null;
    await PreferencesService.remove(PreferencesService.kAccessToken);
    await PreferencesService.remove(PreferencesService.kRefreshToken);
  }

  // ---- Registration (Steps 1-4) + store creation ----

  /// Step 1: sends the OTP to [email] for a new vendor account.
  Future<bool> startRegistration({
    required String ownerName,
    required String mobileNumber,
    required String email,
    required String storeName,
    required String storeDescription,
  }) async {
    lastAuthError = null;
    _pendingEmail = email;
    _pendingOwnerName = ownerName;
    _pendingMobile = mobileNumber;
    _pendingStoreName = storeName;
    _pendingStoreDescription = storeDescription;
    _isBusy = true;
    notifyListeners();
    try {
      await _auth.registerStart(
        fullName: ownerName,
        mobileNumber: mobileNumber,
        email: email,
      );
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Steps 2-3: verify the emailed OTP.
  Future<bool> verifyRegistrationOtp(String code) async {
    lastAuthError = null;
    _isBusy = true;
    notifyListeners();
    try {
      await _auth.verifyRegistrationOtp(email: _pendingEmail ?? '', otpCode: code);
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String> resendRegistrationOtp() async {
    lastAuthError = null;
    try {
      await _auth.registerStart(
        fullName: _pendingOwnerName ?? '',
        mobileNumber: _pendingMobile ?? '',
        email: _pendingEmail ?? '',
      );
    } on AuthException catch (e) {
      lastAuthError = e.message;
    }
    return '';
  }

  /// Step 4: creates the vendor account and signs in. Store details are
  /// collected next (StoreSetupScreen).
  Future<bool> completeRegistration(String password) async {
    lastAuthError = null;
    _isBusy = true;
    notifyListeners();
    try {
      final tokens = await _auth.setPassword(email: _pendingEmail ?? '', password: password);
      await _saveTokens(tokens);
      _client.authToken = tokens.accessToken;
      _mobileNumber = _pendingMobile;
      await PreferencesService.setString(
          PreferencesService.kOwnerMobile, _pendingMobile ?? '');
      _isAuthenticated = true;
      _hasCompletedStoreSetup = false;
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Creates the store (POST /vendor/me) after registration, then loads
  /// the live profile. Returns false and sets [lastAuthError] on failure.
  Future<bool> createStore({
    required String storeName,
    required String description,
    required String address,
    required List<String> categories,
    required DeliverySettings delivery,
    required List<OperatingHours> hours,
  }) async {
    lastAuthError = null;
    _isBusy = true;
    notifyListeners();
    try {
      final dayNames = OperatingHours.defaultWeek().map((h) => h.day).toList();
      await api.createStore({
        'store_name': storeName,
        'description': description.isEmpty ? null : description,
        'address': address,
        'contact_number': _mobileNumber ?? '',
        'categories': categories,
        'delivery_enabled': delivery.deliveryEnabled,
        'pickup_enabled': delivery.pickupEnabled,
        'scheduled_delivery_enabled': delivery.scheduledDeliveryEnabled,
        'base_delivery_fee': delivery.baseDeliveryFee,
        'delivery_barangays': delivery.deliveryBarangays,
        'hours': [
          for (var i = 0; i < hours.length; i++) hours[i].toApi(dayNames.indexOf(hours[i].day)),
        ],
      });
      await _loadStore();
      _hasCompletedStoreSetup = true;
      await PreferencesService.setBool(PreferencesService.kSetupDone, true);
      return true;
    } on StoreApiException catch (e) {
      lastAuthError = e.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Real credential check (login round-trip) for the Change Password flow.
  Future<bool> verifyPassword(String password) async {
    final mobile = _mobileNumber;
    if (mobile == null) return false;
    final error = await _auth.checkCurrentPassword(
      mobileNumber: mobile,
      currentPassword: password,
    );
    return error == null;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      return false;
    }
  }

  /// Vendors are provisioned with a store (seed/admin-created), so a
  /// successful login means setup is done. Kept for the splash routing.
  Future<void> completeStoreSetup() async {
    _hasCompletedStoreSetup = true;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kSetupDone, true);
    await _persistVendor();
  }

  Future<void> setStoreStatus(StoreStatus status) async {
    _vendor.status = status;
    notifyListeners();
    try {
      final json = await api.updateStatus(
        isOpen: status == StoreStatus.open || status == StoreStatus.busy,
        isPaused: status == StoreStatus.paused,
      );
      _vendor = VendorProfile.fromApi(json);
    } on StoreApiException {
      // Reverted on next reload; keep optimistic value meanwhile.
    }
    notifyListeners();
    await _persistVendor();
  }

  /// Quick header toggle: flips between Open and Closed only. For
  /// Busy/Paused, vendors use the dedicated Store Status screen.
  Future<void> toggleStoreOpen(bool open) =>
      setStoreStatus(open ? StoreStatus.open : StoreStatus.closed);

  Future<void> updateProfile({
    String? ownerName,
    String? storeName,
    String? description,
    String? address,
    String? contactNumber,
    String? email,
    String? logoUrl,
    String? bannerUrl,
  }) async {
    // Owner name/email are user-account fields — no backend endpoint yet,
    // so they update the local profile only.
    if (ownerName != null) _vendor.ownerName = ownerName;
    if (email != null) _vendor.email = email;

    final body = <String, dynamic>{
      if (storeName != null) 'store_name': storeName,
      if (description != null) 'description': description,
      if (address != null) 'address': address,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (logoUrl != null) 'logo_url': logoUrl.isEmpty ? null : logoUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl.isEmpty ? null : bannerUrl,
    };

    notifyListeners();
    if (body.isNotEmpty) {
      try {
        final json = await api.updateStore(body);
        _vendor = VendorProfile.fromApi(json);
      } on StoreApiException {
        // Keep optimistic local values; server state wins on next reload.
      }
    }
    notifyListeners();
    await _persistVendor();
  }

  Future<void> updateCategories(List<String> categories) async {
    _vendor.categories = categories;
    notifyListeners();
    try {
      final json = await api.updateCategories(categories);
      _vendor = VendorProfile.fromApi(json);
    } on StoreApiException {
      // keep optimistic value
    }
    notifyListeners();
    await _persistVendor();
  }

  Future<void> updateOperatingHours(List<OperatingHours> hours) async {
    _vendor.operatingHours = hours;
    notifyListeners();
    try {
      final dayNames = OperatingHours.defaultWeek().map((h) => h.day).toList();
      final json = await api.updateHours([
        for (var i = 0; i < hours.length; i++) hours[i].toApi(dayNames.indexOf(hours[i].day)),
      ]);
      _vendor = VendorProfile.fromApi(json);
    } on StoreApiException {
      // keep optimistic value
    }
    notifyListeners();
    await _persistVendor();
  }

  Future<void> updateDeliverySettings(DeliverySettings settings) async {
    _vendor.deliverySettings = settings;
    notifyListeners();
    try {
      final json = await api.updateDeliverySettings(settings.toApi());
      _vendor = VendorProfile.fromApi(json);
    } on StoreApiException {
      // keep optimistic value
    }
    notifyListeners();
    await _persistVendor();
  }

  Future<void> _saveTokens(AuthTokens tokens) async {
    await PreferencesService.setString(PreferencesService.kAccessToken, tokens.accessToken);
    await PreferencesService.setString(PreferencesService.kRefreshToken, tokens.refreshToken);
  }

  Future<void> _persistVendor() async {
    await PreferencesService.setString(
        PreferencesService.kProfile, jsonEncode(_vendor.toJson()));
  }
}
