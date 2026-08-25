import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/vendor.dart';
import '../services/mock_data_service.dart';
import '../services/preferences_service.dart';

class VendorProvider extends ChangeNotifier {
  VendorProvider() {
    _vendor = MockDataService.buildVendor();
  }

  late VendorProfile _vendor;
  bool _isAuthenticated = false;
  bool _hasCompletedStoreSetup = false;
  bool _restored = false;
  String? _accountPassword;

  VendorProfile get vendor => _vendor;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasCompletedStoreSetup => _hasCompletedStoreSetup;
  bool get restored => _restored;

  /// Restores the persisted session and every store configuration
  /// (profile, status, hours, delivery settings, categories, images).
  /// Call once at app start (splash) before routing.
  Future<void> restoreSession() async {
    final authenticated = await PreferencesService.getBool(PreferencesService.kAuthenticated);
    final setupDone = await PreferencesService.getBool(PreferencesService.kSetupDone);
    final profileJson = await PreferencesService.getString(PreferencesService.kProfile);
    _accountPassword = await PreferencesService.getString(PreferencesService.kAccountPassword);

    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        _vendor = VendorProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt payload — fall back to the mock default.
        _vendor = MockDataService.buildVendor();
      }
    }

    _isAuthenticated = authenticated;
    _hasCompletedStoreSetup = setupDone;
    _restored = true;
    notifyListeners();
  }

  Future<void> _persistVendor() async {
    await PreferencesService.setString(
        PreferencesService.kProfile, jsonEncode(_vendor.toJson()));
  }

  /// Signs in and remembers the credential entered so Change Password can
  /// verify the current one later (mock stand-in for backend auth).
  Future<void> signIn({String? password}) async {
    _isAuthenticated = true;
    if (password != null && password.isNotEmpty) {
      _accountPassword = password;
      await PreferencesService.setString(PreferencesService.kAccountPassword, password);
    }
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kAuthenticated, true);
  }

  Future<void> signOut() async {
    _isAuthenticated = false;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kAuthenticated, false);
  }

  /// Mock password check for the Change Password flow — mirrors the
  /// backend's verify-password endpoint.
  Future<bool> verifyPassword(String password) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return _accountPassword != null && _accountPassword == password;
  }

  Future<void> changePassword(String newPassword) async {
    _accountPassword = newPassword;
    await PreferencesService.setString(PreferencesService.kAccountPassword, newPassword);
  }

  Future<void> completeStoreSetup() async {
    _hasCompletedStoreSetup = true;
    notifyListeners();
    await PreferencesService.setBool(PreferencesService.kSetupDone, true);
    await _persistVendor();
  }

  Future<void> setStoreStatus(StoreStatus status) async {
    _vendor.status = status;
    notifyListeners();
    await _persistVendor();
  }

  /// Quick header toggle: flips between Open and Closed only. For
  /// Busy/Paused, vendors use the dedicated Store Status screen.
  Future<void> toggleStoreOpen(bool open) async {
    _vendor.status = open ? StoreStatus.open : StoreStatus.closed;
    notifyListeners();
    await _persistVendor();
  }

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
    if (ownerName != null) _vendor.ownerName = ownerName;
    if (storeName != null) _vendor.storeName = storeName;
    if (description != null) _vendor.description = description;
    if (address != null) _vendor.address = address;
    if (contactNumber != null) _vendor.mobileNumber = contactNumber;
    if (email != null) _vendor.email = email;
    if (logoUrl != null) _vendor.logoUrl = logoUrl;
    if (bannerUrl != null) _vendor.bannerUrl = bannerUrl;
    notifyListeners();
    await _persistVendor();
  }

  Future<void> updateCategories(List<String> categories) async {
    _vendor.categories = categories;
    notifyListeners();
    await _persistVendor();
  }

  Future<void> updateOperatingHours(List<OperatingHours> hours) async {
    _vendor.operatingHours = hours;
    notifyListeners();
    await _persistVendor();
  }

  Future<void> updateDeliverySettings(DeliverySettings settings) async {
    _vendor.deliverySettings = settings;
    notifyListeners();
    await _persistVendor();
  }
}
