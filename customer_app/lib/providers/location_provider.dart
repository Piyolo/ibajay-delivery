import 'dart:convert';

import 'package:flutter/material.dart';

import '../constants/location_constants.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/preferences_service.dart';

/// Address book backed by `GET/POST/DELETE /api/v1/addresses` once signed
/// in, with a per-user SharedPreferences mirror so addresses still work
/// offline AND never leak between accounts on the same device.
///
/// Server IDs are UUIDs — checkout sends [activeAddress].id as address_id.
class LocationProvider extends ChangeNotifier {
  LocationProvider({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  final List<SavedAddress> _addresses = [];
  String? _activeAddressId;
  String? _userId;
  bool _syncing = false;

  /// Count of in-flight add/remove operations. While a mutation is
  /// running, [restore]/[syncFromServer] must not rebuild the list from
  /// the (stale) cache or the server — that would drop the optimistic
  /// entry the mutation just made and desync its server copy.
  int _mutating = 0;

  bool get _canRebuild => _mutating == 0;

  /// Error from the last failed server sync/add/remove (UI display).
  String? lastError;

  static final RegExp _uuidPattern =
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);
  bool get isSyncing => _syncing;
  String? get currentUserId => _userId;

  SavedAddress? get activeAddress {
    if (_addresses.isEmpty) return null;
    try {
      return _addresses.firstWhere((a) => a.id == _activeAddressId);
    } catch (_) {
      return _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.first);
    }
  }

  /// Binds this provider to an account and loads THAT user's cached
  /// addresses. Call when a session becomes known (splash / login). Also
  /// pulls the authoritative list from the server.
  Future<void> attachUser(String uid) async {
    if (_userId == uid && _addresses.isNotEmpty) return;
    _userId = uid;
    await restore();
    await syncFromServer();
  }

  /// Clears in-memory state (used on sign-out so the next account starts
  /// fresh). Other users' cached data stays on disk under their own keys.
  void detachUser() {
    _userId = null;
    _addresses.clear();
    _activeAddressId = null;
    lastError = null;
    notifyListeners();
  }

  /// Loads locally-cached addresses for [_userId].
  Future<void> restore() async {
    final uid = _userId;
    if (uid == null) return;
    if (!_canRebuild) return;
    final raw = await PreferencesService.getString(PreferencesService.kAddressesFor(uid));
    _activeAddressId =
        await PreferencesService.getString(PreferencesService.kActiveAddressIdFor(uid));
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
            .toList();
        _addresses
          ..clear()
          ..addAll(list);
      } catch (_) {
        // Corrupt payload — start fresh rather than crash.
      }
    } else {
      _addresses.clear();
      _activeAddressId = null;
    }
    notifyListeners();
  }

  /// Pulls the saved address book from the backend for the signed-in user.
  /// Local entries that never reached the server are preserved.
  Future<void> syncFromServer() async {
    if (_api.authToken == null || _syncing || _userId == null) return;
    if (!_canRebuild) return;
    _syncing = true;
    notifyListeners();
    try {
      final data = await _api.get('/addresses') as List;
      final server = data.map((e) => _addressFromApi(e as Map<String, dynamic>)).toList();
      // Keep device-only addresses (created while offline) at the end.
      final localOnly =
          _addresses.where((a) => !_uuidPattern.hasMatch(a.id)).toList();
      _addresses
        ..clear()
        ..addAll([...server, ...localOnly]);
      if (_activeAddressId != null && !_addresses.any((a) => a.id == _activeAddressId)) {
        _activeAddressId = _addresses.isNotEmpty ? _addresses.first.id : null;
      }
      lastError = null;
      await _persist();
    } on ApiException catch (e) {
      lastError = e.message;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final uid = _userId;
    if (uid == null) return;
    await PreferencesService.setString(
      PreferencesService.kAddressesFor(uid),
      jsonEncode(_addresses.map((a) => a.toJson()).toList()),
    );
    if (_activeAddressId != null) {
      await PreferencesService.setString(
          PreferencesService.kActiveAddressIdFor(uid), _activeAddressId!);
    } else {
      await PreferencesService.remove(PreferencesService.kActiveAddressIdFor(uid));
    }
  }

  Future<void> addAddress(SavedAddress address) async {
    _mutating++;
    try {
      if (_addresses.isEmpty) address.isDefault = true;
      if (address.isDefault) {
        for (final a in _addresses) {
          a.isDefault = false;
        }
      }
      // Optimistic local add; swap in the server copy once created.
      _addresses.add(address);
      _activeAddressId = address.id;
      notifyListeners();
      await _persist();

      if (_api.authToken == null) return;
      try {
        final created = await _api.post('/addresses', body: {
          'label': address.label,
          'full_address': address.fullAddress,
          'barangay': address.barangay,
          'latitude': address.latitude,
          'longitude': address.longitude,
          'landmark': address.landmark,
          'is_default': address.isDefault,
        }) as Map<String, dynamic>;
        final saved = _addressFromApi(created);
        final index = _addresses.indexWhere((a) => a.id == address.id);
        if (index >= 0) _addresses[index] = saved;
        if (_activeAddressId == address.id) _activeAddressId = saved.id;
        lastError = null;
      } on ApiException catch (e) {
        // Kept locally with its temporary ID; retried on next successful add.
        lastError = e.message;
      }
      notifyListeners();
      await _persist();
    } finally {
      _mutating--;
    }
  }

  Future<void> removeAddress(String id) async {
    _mutating++;
    try {
      _addresses.removeWhere((a) => a.id == id);
      if (_activeAddressId == id) {
        _activeAddressId = _addresses.isNotEmpty ? _addresses.first.id : null;
      }
      notifyListeners();
      await _persist();

      if (_api.authToken == null || !_uuidPattern.hasMatch(id)) return;
      try {
        await _api.delete('/addresses/$id');
        lastError = null;
      } on ApiException catch (e) {
        lastError = e.message;
      }
    } finally {
      _mutating--;
    }
  }

  Future<void> setActive(String id) async {
    _activeAddressId = id;
    notifyListeners();
    await _persist();
  }

  /// Saves the location picked on the "Location Setup" screen (used by
  /// BOTH onboarding and the home screen's address chip).
  ///
  /// This NEVER deletes other saved addresses: an earlier version wiped
  /// every "Home"-labelled entry server-side (which is how most Manage
  /// Addresses entries were stored), so re-picking a location from the
  /// top bar silently emptied the address book. Instead:
  ///  - an identical address already saved is simply made active, and
  ///  - otherwise the new pick is APPENDED and becomes active.
  Future<void> saveInitialLocation({
    required String fullAddress,
    required String barangay,
    required double lat,
    required double lng,
  }) async {
    // Same spot already saved (re-picking the current location) → just
    // switch to it instead of stacking a duplicate entry.
    SavedAddress? duplicate;
    for (final a in _addresses) {
      if (a.barangay == barangay && a.fullAddress == fullAddress) {
        duplicate = a;
        break;
      }
    }
    if (duplicate != null) {
      await setActive(duplicate.id);
      return;
    }

    await addAddress(SavedAddress(
      id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
      label: 'Home',
      fullAddress: fullAddress,
      barangay: barangay,
      latitude: lat,
      longitude: lng,
      isDefault: true,
    ));
  }

  /// Reference point used for "nearby vendors".
  double get referenceLat => activeAddress?.latitude ?? LocationConstants.townLat;
  double get referenceLng => activeAddress?.longitude ?? LocationConstants.townLng;

  /// Barangay of the active address — drives barangay-based delivery
  /// availability. Empty when no address is saved yet.
  String get referenceBarangay => activeAddress?.barangay ?? '';

  SavedAddress _addressFromApi(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Home',
        fullAddress: json['full_address'] as String? ?? '',
        barangay: json['barangay'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        landmark: json['landmark'] as String? ?? '',
        isDefault: json['is_default'] as bool? ?? false,
      );
}
