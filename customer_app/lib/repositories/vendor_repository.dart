import '../models/review.dart';
import '../models/vendor.dart';

/// Abstraction over "where vendor/menu/review data comes from."
///
/// [MockVendorRepository] (JSON assets) is the only implementation during
/// the frontend-mockup stage. Once the FastAPI backend is ready, add an
/// `ApiVendorRepository` that calls `/api/v1/vendors/nearby` and
/// `/api/v1/vendors/{id}` instead, and swap the single line in
/// `VendorProvider`'s constructor — nothing else in the app needs to change.
abstract class VendorRepository {
  Future<List<VendorProfile>> fetchVendors();
  Future<List<VendorReview>> fetchReviews(String vendorId);
}
