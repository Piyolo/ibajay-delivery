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

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  String searchQuery = '';
  String? selectedCategory;
  bool filterOpenNow = false;
  bool filterDeliveryAvailable = false;
  bool filterPickupAvailable = false;
  bool filterScheduledAvailable = false;

  /// Called once at app startup (see SplashScreen) before any screen that
  /// needs vendor data is shown. Safe to call more than once — subsequent
  /// calls are a no-op once loaded.
  Future<void> load() async {
    if (_isLoaded || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    _vendors = await _repository.fetchVendors();
    final reviewEntries = await Future.wait(
      _vendors.map((v) async => MapEntry(v.id, await _repository.fetchReviews(v.id))),
    );
    _reviewsByVendor = Map.fromEntries(reviewEntries);

    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  List<VendorProfile> get allVendors => _vendors;

  List<String> get categories =>
      _vendors.expand((v) => v.categories).toSet().toList()..sort();

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
  List<FoodItemRef> get featuredFoodItems => _vendors
      .expand((v) => v.menu.where((f) => f.isFeatured && f.isAvailable))
      .toList();

  /// Popular Stores — highest rated vendors, for the Home screen's
  /// "Popular Stores" carousel.
  List<VendorProfile> get popularVendors {
    final sorted = [..._vendors]..sort((a, b) => b.rating.compareTo(a.rating));
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
      if (selectedCategory != null && !v.categories.contains(selectedCategory)) return false;
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
