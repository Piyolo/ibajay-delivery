class StorePromotion {
  final String id;
  String title;
  String description;
  String discountType; // percent | fixed
  double discountValue;
  String? code; // null = auto-applied store-wide
  double minSubtotal;
  DateTime? startsAt;
  DateTime? endsAt;
  bool isActive;
  int timesUsed;

  StorePromotion({
    required this.id,
    required this.title,
    this.description = '',
    required this.discountType,
    required this.discountValue,
    this.code,
    this.minSubtotal = 0,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.timesUsed = 0,
  });

  factory StorePromotion.fromApi(Map<String, dynamic> json) {
    DateTime? parse(String? raw) => raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    return StorePromotion(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      discountType: json['discount_type'] as String? ?? 'percent',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      code: json['code'] as String?,
      minSubtotal: (json['min_subtotal'] as num?)?.toDouble() ?? 0,
      startsAt: parse(json['starts_at'] as String?),
      endsAt: parse(json['ends_at'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      timesUsed: (json['times_used'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCreateApi() => {
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'discount_type': discountType,
        'discount_value': discountValue,
        'code': code,
        'min_subtotal': minSubtotal,
        if (startsAt != null) 'starts_at': startsAt!.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
      };

  /// Human-readable summary, e.g. "20% off" or "₱50 off".
  String get discountLabel =>
      discountType == 'percent'
          ? '${discountValue.toStringAsFixed(discountValue == discountValue.roundToDouble() ? 0 : 2)}% off'
          : '₱${discountValue.toStringAsFixed(0)} off';
}
