class ChatMessage {
  final String id;
  final String senderId; // 'me' or vendor id
  final String? content;
  final String? imageUrl;
  final DateTime createdAt;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.content,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
  });
}

class ChatThread {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorLogoUrl;
  final String? orderId;
  final List<ChatMessage> messages;

  ChatThread({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.vendorLogoUrl = '',
    this.orderId,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;
  int get unreadCount => messages.where((m) => !m.isRead && m.senderId != 'me').length;
}
