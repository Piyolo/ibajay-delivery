import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/review.dart';
import '../models/vendor.dart';
import 'vendor_repository.dart';

/// Reads vendor/menu/review data from `assets/data/*.json`.
///
/// This is a deliberate stand-in for a real network call: the async
/// signature matches what an HTTP repository would look like, so the rest
/// of the app (providers, screens) never has to change when the backend
/// is wired in later — only this class gets replaced.
class MockVendorRepository implements VendorRepository {
  List<VendorProfile>? _vendorsCache;
  Map<String, List<VendorReview>>? _reviewsCache;

  Future<void> _ensureLoaded() async {
    if (_vendorsCache != null && _reviewsCache != null) return;

    final vendorsRaw = await rootBundle.loadString('assets/data/vendors.json');
    final vendorsJson = jsonDecode(vendorsRaw) as List;
    _vendorsCache = vendorsJson
        .map((e) => VendorProfile.fromJson(e as Map<String, dynamic>))
        .toList();

    final reviewsRaw = await rootBundle.loadString('assets/data/reviews.json');
    final reviewsJson = jsonDecode(reviewsRaw) as Map<String, dynamic>;
    _reviewsCache = reviewsJson.map(
      (vendorId, list) => MapEntry(
        vendorId,
        (list as List).map((e) => VendorReview.fromJson(e as Map<String, dynamic>)).toList(),
      ),
    );
  }

  @override
  Future<List<VendorProfile>> fetchVendors({double? refLat, double? refLng}) async {
    await _ensureLoaded();
    // Simulate real network latency so loading states are actually exercised.
    await Future.delayed(const Duration(milliseconds: 300));
    return _vendorsCache!;
  }

  @override
  Future<List<VendorReview>> fetchReviews(String vendorId) async {
    await _ensureLoaded();
    return _reviewsCache![vendorId] ?? [];
  }
}
