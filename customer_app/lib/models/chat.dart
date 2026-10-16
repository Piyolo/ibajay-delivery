class ChatMessage {
  final String id;
  final String senderId; // real user id from the backend
  final String? content;
  final String? imageUrl;
  final DateTime createdAt;
  bool isRead;
  final bool fromMe;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.content,
    this.imageUrl,
    required this.createdAt,
    this.isRead = false,
    this.fromMe = false,
  });

  factory ChatMessage.fromApi(Map<String, dynamic> json, {required String myUserId}) {
    final senderId = json['sender_id'] as String? ?? '';
    return ChatMessage(
      id: json['id'] as String,
      senderId: senderId,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      fromMe: senderId == myUserId,
    );
  }
}

class ChatThread {
  final String id;
  final String vendorId;
  final String vendorName;
  final String vendorLogoUrl;
  final String? orderId;
  final List<ChatMessage> messages;

  // Summary fields from the thread-list endpoint (the list payload does
  // NOT include full messages — history loads when a thread opens).
  String? lastMessageText;
  DateTime? lastMessageAt;
  int messageCount;

  // Server-side unread tally from the thread-list payload (GET /chats/my
  // `unread_count`): messages the requester did not send that are still
  // unread. Null when the row didn't carry the field.
  int? serverUnreadCount;

  ChatThread({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.vendorLogoUrl = '',
    this.orderId,
    List<ChatMessage>? messages,
    this.lastMessageText,
    this.lastMessageAt,
    this.messageCount = 0,
    this.serverUnreadCount,
  }) : messages = messages ?? [];

  /// Latest activity for previews: live messages win over the summary.
  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;
  String? get previewText =>
      lastMessage?.content?.isNotEmpty == true ? lastMessage!.content : lastMessageText;
  DateTime? get previewTime => lastMessage?.createdAt ?? lastMessageAt;

  /// Unread messages from the other side. An opened thread (non-empty
  /// [messages], kept fresh by history loads and the live WebSocket)
  /// owns live truth and derives the count from its messages; a
  /// never-opened thread only knows what the list payload summarized,
  /// so it falls back to the server's `unread_count` (0 when absent).
  int get unreadCount => messages.isNotEmpty
      ? messages.where((m) => !m.isRead && !m.fromMe).length
      : serverUnreadCount ?? 0;
}
