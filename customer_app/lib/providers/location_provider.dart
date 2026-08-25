import 'dart:convert';

import 'package:flutter/material.dart';

import '../constants/location_constants.dart';
import '../models/user.dart';
import '../services/preferences_service.dart';

class LocationProvider extends ChangeNotifier {
  final List<SavedAddress> _addresses = [];
  String? _activeAddressId;

  List<SavedAddress> get addresses => List.unmodifiable(_addresses);

  SavedAddress? get activeAddress {
    if (_addresses.isEmpty) return null;
    try {
      return _addresses.firstWhere((a) => a.id == _activeAddressId);
    } catch (_) {
      return _addresses.firstWhere((a) => a.isDefault, orElse: () => _addresses.first);
    }
  }

  /// Restores saved addresses. Call once at app start (splash).
  Future<void> restore() async {
    final raw = await PreferencesService.getString(PreferencesService.kAddresses);
    _activeAddressId = await PreferencesService.getString(PreferencesService.kActiveAddressId);
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
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await PreferencesService.setString(
      PreferencesService.kAddresses,
      jsonEncode(_addresses.map((a) => a.toJson()).toList()),
    );
    if (_activeAddressId != null) {
      await PreferencesService.setString(PreferencesService.kActiveAddressId, _activeAddressId!);
    } else {
      await PreferencesService.remove(PreferencesService.kActiveAddressId);
    }
  }

  Future<void> addAddress(SavedAddress address) async {
    if (address.isDefault) {
      for (final a in _addresses) {
        a.isDefault = false;
      }
    }
    if (_addresses.isEmpty) address.isDefault = true;
    _addresses.add(address);
    _activeAddressId = address.id;
    notifyListeners();
    await _persist();
  }

  Future<void> removeAddress(String id) async {
    _addresses.removeWhere((a) => a.id == id);
    if (_activeAddressId == id) _activeAddressId = _addresses.isNotEmpty ? _addresses.first.id : null;
    notifyListeners();
    await _persist();
  }

  Future<void> setActive(String id) async {
    _activeAddressId = id;
    notifyListeners();
    await _persist();
  }

  /// Convenience for the initial "Location Setup" onboarding step.
  Future<void> saveInitialLocation({
    required String fullAddress,
    required String barangay,
    required double lat,
    required double lng,
  }) async {
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

  /// Reference point used for "nearby vendors" until real GPS/Places is wired in.
  double get referenceLat => activeAddress?.latitude ?? LocationConstants.townLat;
  double get referenceLng => activeAddress?.longitude ?? LocationConstants.townLng;

  /// Barangay of the active address — drives barangay-based delivery
  /// availability. Empty when no address is saved yet.
  String get referenceBarangay => activeAddress?.barangay ?? '';
}
