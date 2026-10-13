/// A row from `GET /notifications` — the customer's in-app feed of order
/// (and other) events, newest first.
class AppNotification {
  final String id;
  final String title;
  final String body;

  /// Event kind from the backend (e.g. `order_status`, `chat`, `promo`) —
  /// drives the leading icon.
  final String type;

  /// Order this notification refers to; tapping opens its tracking screen.
  final String? relatedOrderId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = '',
    this.relatedOrderId,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? '',
        relatedOrderId: json['related_order_id'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
