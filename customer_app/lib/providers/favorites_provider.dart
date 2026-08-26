import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

/// Favorites persist locally, per account — switching users on the same
/// device never shares favorites. (Backend favorites endpoint is still
/// pending; these are device-local by design for now.)
class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteVendorIds = {};
  final Set<String> _favoriteFoodIds = {};
  String? _userId;

  bool isVendorFavorite(String id) => _favoriteVendorIds.contains(id);
  bool isFoodFavorite(String id) => _favoriteFoodIds.contains(id);

  Set<String> get favoriteVendorIds => _favoriteVendorIds;
  Set<String> get favoriteFoodIds => _favoriteFoodIds;

  /// Binds this provider to an account and loads THAT user's favorites.
  Future<void> attachUser(String uid) async {
    if (_userId == uid && _favoriteVendorIds.isNotEmpty) return;
    _userId = uid;
    await restore();
  }

  /// Clears in-memory state (on sign-out). Other accounts' data stays
  /// safely under their own keys.
  void detachUser() {
    _userId = null;
    _favoriteVendorIds.clear();
    _favoriteFoodIds.clear();
    notifyListeners();
  }

  Future<void> restore() async {
    final uid = _userId;
    if (uid == null) return;
    _favoriteVendorIds
      ..clear()
      ..addAll(await PreferencesService.getStringList(PreferencesService.kFavoriteVendorsFor(uid)));
    _favoriteFoodIds
      ..clear()
      ..addAll(await PreferencesService.getStringList(PreferencesService.kFavoriteFoodsFor(uid)));
    notifyListeners();
  }

  Future<void> toggleVendor(String id) async {
    final uid = _userId;
    if (_favoriteVendorIds.contains(id)) {
      _favoriteVendorIds.remove(id);
    } else {
      _favoriteVendorIds.add(id);
    }
    notifyListeners();
    if (uid == null) return;
    await PreferencesService.setStringList(
        PreferencesService.kFavoriteVendorsFor(uid), _favoriteVendorIds.toList());
  }

  Future<void> toggleFood(String id) async {
    final uid = _userId;
    if (_favoriteFoodIds.contains(id)) {
      _favoriteFoodIds.remove(id);
    } else {
      _favoriteFoodIds.add(id);
    }
    notifyListeners();
    if (uid == null) return;
    await PreferencesService.setStringList(
        PreferencesService.kFavoriteFoodsFor(uid), _favoriteFoodIds.toList());
  }
}
