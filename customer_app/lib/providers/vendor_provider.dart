import 'dart:math';

import 'package:flutter/material.dart';

import '../models/review.dart';
import '../models/vendor.dart';
import '../repositories/api_vendor_repository.dart';
import '../repositories/mock_vendor_repository.dart';
import '../repositories/vendor_repository.dart';
import '../services/app_config.dart';

class VendorProvider extends ChangeNotifier {
  VendorProvider({VendorRepository? repository})
      : _repository = repository ??
            (AppConfig.useMockData ? MockVendorRepository() : ApiVendorRepository());

  final VendorRepository _repository;

  List<VendorProfile> _vendors = [];
  Map<String, List<VendorReview>> _reviewsByVendor = {};
  bool _isLoading = false;
  bool _isLoaded = false;

  /// Error from the last failed load (shown by the Home screen with a
  /// retry button). Null after a successful load.
  String? lastError;

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  String searchQuery = '';
  String? selectedCategory;
  bool filterOpenNow = false;
  bool filterDeliveryAvailable = false;
  bool filterPickupAvailable = false;
  bool filterScheduledAvailable = false;

  /// Loads vendor data once at app startup (see SplashScreen) before any
  /// screen that needs it is shown. Never throws: a failed load leaves
  /// the app browsable (empty list) and reports via [lastError] instead
  /// of hanging the splash forever. Passes the customer's reference point
  /// so the backend ranks stores by real distance.
  Future<void> load({double? refLat, double? refLng}) async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      _vendors = await _repository.fetchVendors(refLat: refLat, refLng: refLng);
      final reviewEntries = await Future.wait(
        _vendors.map((v) async => MapEntry(v.id, await _repository.fetchReviews(v.id))),
      );
      _reviewsByVendor = Map.fromEntries(reviewEntries);
      _isLoaded = true;
    } catch (error) {
      // Transport/HTTP failure: surface it, keep any previous data, and
      // let [reload] try again later.
      lastError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Forces a fresh fetch (retry button / pull-to-refresh).
  Future<void> reload({double? refLat, double? refLng}) async {
    _isLoaded = false;
    await load(refLat: refLat, refLng: refLng);
  }

  List<VendorProfile> get allVendors => _vendors;

  List<String> get categories {
    // Chips must reflect BOTH data sources: the vendor's own tags
    // (VendorCategory, e.g. "Grocery") and the categories carried by its
    // menu items (FoodCategory, e.g. "Meals") — a store can have items in
    // a category it isn't tagged with, and picking a chip that matched
    // nothing made the filter look broken.
    final names = <String>{};
    for (final v in _vendors) {
      names.addAll(v.categories);
      names.addAll(v.menu.map((f) => f.category).where((c) => c.isNotEmpty));
    }
    return names.toList()..sort();
  }

  /// Whether [vendor] belongs to [category], matching the vendor's tags
  /// OR any of its menu items' categories (case-insensitive — backend
  /// category names are free text).
  bool _matchesCategory(VendorProfile vendor, String category) {
    final wanted = category.trim().toLowerCase();
    if (wanted.isEmpty) return true;
    if (vendor.categories.any((c) => c.trim().toLowerCase() == wanted)) {
      return true;
    }
    return vendor.menu.any(
        (f) => f.category.trim().toLowerCase() == wanted);
  }

  VendorProfile? vendorById(String id) {
    try {
      return _vendors.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  List<VendorReview> reviewsFor(String vendorId) => _reviewsByVendor[vendorId] ?? [];

  /// Featured foods for the Home screen's "Featured Foods" carousel —
  /// items flagged `isFeatured` in the data source, across all vendors.
  /// Respects the selected category (matched against the ITEM's own
  /// category) so tapping a chip visibly filters every section, not just
  /// Nearby Stores.
  List<FoodItemRef> get featuredFoodItems {
    final wanted = selectedCategory?.trim().toLowerCase();
    return _vendors
        .expand((v) => v.menu.where((f) =>
            f.isFeatured &&
            f.isAvailable &&
            (wanted == null || f.category.trim().toLowerCase() == wanted)))
        .toList();
  }

  /// Popular Stores — highest rated vendors, for the Home screen's
  /// "Popular Stores" carousel. Filtered by the selected category too.
  List<VendorProfile> get popularVendors {
    final category = selectedCategory;
    final sorted = _vendors
        .where((v) => category == null || _matchesCategory(v, category))
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(8).toList();
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLng = (lng2 - lng1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Nearby Stores — vendors that can serve the customer's location,
  /// sorted closest-first, with active filters applied. Delivery coverage
  /// is barangay-based: a vendor with a delivery-area list must include
  /// the customer's barangay; vendors without a list fall back to the
  /// legacy distance radius. This backs both the Home screen's
  /// "Nearby Stores" section and the full Store Listing screen.
  List<MapEntry<VendorProfile, double>> nearbyVendors({
    required double refLat,
    required double refLng,
    String refBarangay = '',
  }) {
    final list = _vendors.where((v) {
      if (filterOpenNow && !v.isOpen) return false;
      if (filterDeliveryAvailable && !v.deliverySettings.deliveryEnabled) return false;
      if (filterPickupAvailable && !v.deliverySettings.pickupEnabled) return false;
      if (filterScheduledAvailable && !v.deliverySettings.scheduledDeliveryEnabled) return false;
      if (selectedCategory != null && !_matchesCategory(v, selectedCategory!)) return false;
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final matchesStore = v.storeName.toLowerCase().contains(q);
        final matchesFood = v.menu.any((f) => f.name.toLowerCase().contains(q));
        if (!matchesStore && !matchesFood) return false;
      }
      return true;
    }).toList();

    final withDistance = list
        .map((v) => MapEntry(v, _distanceKm(refLat, refLng, v.latitude, v.longitude)))
        .where((e) => _servesCustomer(e.key, refBarangay, e.value))
        .toList();

    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance;
  }

  /// Whether [vendor] can receive an order from the customer's barangay.
  /// Vendors with a delivery-area list must serve the customer's barangay;
  /// vendors without one fall back to the legacy distance radius.
  bool _servesCustomer(VendorProfile vendor, String refBarangay, double distanceKm) {
    final settings = vendor.deliverySettings;
    if (settings.hasDeliveryAreas) {
      if (refBarangay.isEmpty) return true; // can't determine — show while browsing
      return settings.deliversToBarangay(refBarangay);
    }
    return distanceKm <= settings.deliveryRadiusKm;
  }

  /// Whether [vendor] can deliver to a customer at [barangay]/[lat]/[lng].
  /// Same rule as browse filtering, exposed for checkout so delivery can't
  /// be offered to addresses the store doesn't cover.
  bool servesCustomer(
    VendorProfile vendor, {
    required String barangay,
    required double lat,
    required double lng,
  }) {
    return _servesCustomer(
      vendor,
      barangay,
      _distanceKm(lat, lng, vendor.latitude, vendor.longitude),
    );
  }

  void setSearch(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void setCategory(String? category) {
    selectedCategory = category;
    notifyListeners();
  }

  void toggleOpenNow() {
    filterOpenNow = !filterOpenNow;
    notifyListeners();
  }

  void toggleDelivery() {
    filterDeliveryAvailable = !filterDeliveryAvailable;
    notifyListeners();
  }

  void togglePickup() {
    filterPickupAvailable = !filterPickupAvailable;
    notifyListeners();
  }

  void toggleScheduled() {
    filterScheduledAvailable = !filterScheduledAvailable;
    notifyListeners();
  }

  void clearFilters() {
    filterOpenNow = false;
    filterDeliveryAvailable = false;
    filterPickupAvailable = false;
    filterScheduledAvailable = false;
    selectedCategory = null;
    notifyListeners();
  }
}
