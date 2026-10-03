class VendorReview {
  final String id;
  final String customerName;
  final int stars;
  final String comment;
  final List<String> photoUrls;
  final DateTime createdAt;
  final String? vendorResponse;

  VendorReview({
    required this.id,
    required this.customerName,
    required this.stars,
    this.comment = '',
    List<String>? photoUrls,
    required this.createdAt,
    this.vendorResponse,
  }) : photoUrls = photoUrls ?? [];

  /// Maps the backend's review payload (GET /vendors/{id}/reviews).
  factory VendorReview.fromApi(Map<String, dynamic> json) {
    return VendorReview(
      id: json['id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Anonymous',
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      vendorResponse: json['vendor_response'] as String?,
    );
  }

  /// Offline mock-asset payload (camelCase, relative recency).
  factory VendorReview.fromJson(Map<String, dynamic> json) {
    final daysAgo = (json['daysAgo'] as num?)?.toInt() ?? 0;
    return VendorReview(
      id: json['id'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Anonymous',
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String? ?? '',
      createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
      vendorResponse: json['vendorResponse'] as String?,
    );
  }
}
