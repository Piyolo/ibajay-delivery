import '../models/review.dart';
import '../models/vendor.dart';

/// Abstraction over "where vendor/menu/review data comes from."
///
/// [ApiVendorRepository] is the live implementation against the FastAPI
/// backend. [MockVendorRepository] (JSON assets) remains available as an
/// explicit dev tool via the USE_MOCK_DATA dart-define — it is never used
/// at runtime by default and never serves as an error fallback.
abstract class VendorRepository {
  Future<List<VendorProfile>> fetchVendors({double? refLat, double? refLng});
  Future<List<VendorReview>> fetchReviews(String vendorId);
}
