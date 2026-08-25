import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

/// Favorites persist locally so they survive app restarts.
class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteVendorIds = {};
  final Set<String> _favoriteFoodIds = {};

  bool isVendorFavorite(String id) => _favoriteVendorIds.contains(id);
  bool isFoodFavorite(String id) => _favoriteFoodIds.contains(id);

  Set<String> get favoriteVendorIds => _favoriteVendorIds;
  Set<String> get favoriteFoodIds => _favoriteFoodIds;

  /// Restores saved favorites. Call once at app start (splash).
  Future<void> restore() async {
    _favoriteVendorIds
      ..clear()
      ..addAll(await PreferencesService.getStringList(PreferencesService.kFavoriteVendors));
    _favoriteFoodIds
      ..clear()
      ..addAll(await PreferencesService.getStringList(PreferencesService.kFavoriteFoods));
    notifyListeners();
  }

  Future<void> toggleVendor(String id) async {
    if (_favoriteVendorIds.contains(id)) {
      _favoriteVendorIds.remove(id);
    } else {
      _favoriteVendorIds.add(id);
    }
    notifyListeners();
    await PreferencesService.setStringList(
        PreferencesService.kFavoriteVendors, _favoriteVendorIds.toList());
  }

  Future<void> toggleFood(String id) async {
    if (_favoriteFoodIds.contains(id)) {
      _favoriteFoodIds.remove(id);
    } else {
      _favoriteFoodIds.add(id);
    }
    notifyListeners();
    await PreferencesService.setStringList(
        PreferencesService.kFavoriteFoods, _favoriteFoodIds.toList());
  }
}
