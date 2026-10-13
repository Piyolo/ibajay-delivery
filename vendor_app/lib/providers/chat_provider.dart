import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api_client.dart';

class VendorChatMessage {
  final String id;
  final String senderId;
  final String? content;
  final String? imageUrl;
  bool isRead;
  final DateTime createdAt;

  VendorChatMessage({
    required this.id,
    required this.senderId,
    this.content,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory VendorChatMessage.fromApi(Map<String, dynamic> json, String myUserId) {
    return VendorChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  bool fromMe(String myUserId) => senderId == myUserId;
}

class VendorChatThread {
  final String id;
  String customerName;
  final String? customerId;
  String? orderId;

  /// Customer's mobile from the thread payload — powers "Call customer"
  /// even when the thread has no linked order.
  String? customerMobile;
  final List<VendorChatMessage> messages;

  // Summary fields from GET /chats/vendor — the thread-list payload does NOT
  // include full messages (history loads when a thread opens), so the chat
  // list previews live off these until messages are loaded.
  String? lastMessageText;
  DateTime? lastMessageAt;
  String? lastSenderId;
  int messageCount;

  VendorChatThread({
    required this.id,
    required this.customerName,
    this.customerId,
    this.orderId,
    this.customerMobile,
    List<VendorChatMessage>? messages,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastSenderId,
    this.messageCount = 0,
  }) : messages = messages ?? [];

  /// Latest activity for previews: live messages win over the summary.
  VendorChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  String? get previewText {
    final live = lastMessage?.content;
    if (live != null && live.trim().isNotEmpty) return live;
    final summary = lastMessageText;
    return (summary != null && summary.trim().isNotEmpty) ? summary : null;
  }

  DateTime? get previewTime => lastMessage?.createdAt ?? lastMessageAt;

  /// Copies server summary fields onto an already-known thread WITHOUT ever
  /// touching its in-memory [messages] — a background refetch must never
  /// destroy an open chat's history.
  void adoptSummary(VendorChatThread summary) {
    if (summary.customerName.isNotEmpty) customerName = summary.customerName;
    if (summary.customerMobile?.isNotEmpty ?? false) {
      customerMobile = summary.customerMobile;
    }
    // The backend only ever links a thread to its FIRST order, so a null
    // order_id on the server must not wipe a locally-known link.
    if (summary.orderId != null) orderId = summary.orderId;
    // Preserve the existing preview when the server returns no/empty
    // last_message instead of blanking it.
    final text = summary.lastMessageText;
    if (text != null && text.trim().isNotEmpty) {
      lastMessageText = text;
      lastMessageAt = summary.lastMessageAt;
      lastSenderId = summary.lastSenderId;
      messageCount = summary.messageCount;
    }
  }

  /// Records a locally-known message as the thread's latest preview so the
  /// chat list is correct immediately, without waiting for a refetch.
  void notePreview(VendorChatMessage message) {
    final content = message.content;
    if (content != null && content.trim().isNotEmpty) {
      lastMessageText = content;
      lastMessageAt = message.createdAt;
      lastSenderId = message.senderId;
    }
    messageCount += 1;
  }
}

/// Real chat for the store: threads from `GET /chats/vendor`, history from
/// `GET /chats/{id}/messages`, and live delivery over `ws /ws/chats/{id}`.
class ChatProvider extends ChangeNotifier {
  ChatProvider({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  final List<VendorChatThread> _threads = [];
  WebSocketChannel? _channel;
  String? _connectedThreadId;
  bool _isLoading = false;
  String _myUserId = '';
  String? lastError;

  // Number of chat screens currently open on the nav stack. Polling (e.g.
  // MainShell's 25s timer) skips loadThreads while > 0 so the open
  // conversation is never churned underneath the user.
  int _openChats = 0;

  bool get isLoading => _isLoading;
  List<VendorChatThread> get threads => List.unmodifiable(_threads);

  /// True while a chat screen is open (pushed above the shell).
  bool get hasOpenChat => _openChats > 0;

  /// The signed-in vendor's user id (for mine/theirs bubble alignment).
  String get myUserId => _myUserId;

  VendorChatThread? threadById(String id) {
    try {
      return _threads.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheMyUserId() async {
    if (_myUserId.isNotEmpty) return;
    try {
      final me = await _client.get('/auth/me') as Map<String, dynamic>;
      _myUserId = me['id'] as String? ?? '';
    } on ApiException {
      // Messages will still render; only the mine/theirs split degrades.
    }
  }

  /// Pulls the store's chat threads and MERGES them into the current state.
  /// It only ever refreshes thread-list previews — it never touches a
  /// thread's loaded [VendorChatThread.messages], and a failed fetch keeps
  /// the previous thread list instead of blanking it.
  Future<void> loadThreads() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cacheMyUserId();
      final rows = await _client.get('/chats/vendor') as List<dynamic>;
      _mergeThreads(rows.map((r) {
        final m = r as Map<String, dynamic>;
        return VendorChatThread(
          id: m['id'] as String,
          customerName: m['customer_name'] as String? ?? 'Customer',
          customerId: m['customer_id'] as String?,
          customerMobile: m['customer_mobile'] as String?,
          orderId: m['order_id'] as String?,
          lastMessageText: m['last_message'] as String?,
          lastMessageAt:
              DateTime.tryParse(m['last_message_at'] as String? ?? '')?.toLocal(),
          lastSenderId: m['last_sender_id'] as String?,
          messageCount: m['message_count'] as int? ?? 0,
        );
      }).toList());
      lastError = null;
    } on ApiException catch (e) {
      // Keep the previous thread list — a failed poll must never blank the
      // inbox or destroy an open chat's state.
      lastError = e.message;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Merges server summaries into the existing threads IN PLACE. Existing
  /// thread objects (and their loaded message history) are preserved; only
  /// preview metadata is refreshed. Threads whose summary comes back
  /// missing/empty keep whatever the client already showed.
  void _mergeThreads(List<VendorChatThread> incoming) {
    final existing = {for (final t in _threads) t.id: t};
    final merged = <VendorChatThread>[];
    for (final server in incoming) {
      final local = existing[server.id];
      if (local == null) {
        merged.add(server);
      } else {
        local.adoptSummary(server);
        merged.add(local);
      }
    }
    // Never drop the thread a chat screen is actively using.
    final openId = _connectedThreadId;
    if (openId != null &&
        existing.containsKey(openId) &&
        !merged.any((t) => t.id == openId)) {
      merged.insert(0, existing[openId]!);
    }
    _threads
      ..clear()
      ..addAll(merged);
  }

  /// Loads history and opens the live socket for [threadId].
  Future<void> connect(String threadId) async {
    _openChats++;
    await _cacheMyUserId();
    // Ensure the thread exists in state even if loadThreads hasn't run.
    if (threadById(threadId) == null) {
      _threads.insert(0, VendorChatThread(id: threadId, customerName: 'Customer'));
      notifyListeners();
    }
    await _loadHistory(threadId);
    await _openSocket(threadId);
  }

  Future<void> _loadHistory(String threadId) async {
    try {
      final rows = await _client.get('/chats/$threadId/messages') as List<dynamic>;
      final thread = threadById(threadId);
      if (thread == null) return;
      thread.messages
        ..clear()
        ..addAll(rows.map((r) => VendorChatMessage.fromApi(r as Map<String, dynamic>, _myUserId)));
      // Keep the list preview in sync with the freshly-loaded history.
      final last = thread.messages.isEmpty ? null : thread.messages.last;
      if (last != null && (last.content?.trim().isNotEmpty ?? false)) {
        thread.lastMessageText = last.content;
        thread.lastMessageAt = last.createdAt;
        thread.lastSenderId = last.senderId;
      }
      thread.messageCount = thread.messages.length;
      lastError = null;
      notifyListeners();
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<void> _openSocket(String threadId) async {
    await _closeSocket();
    final token = _client.authToken;
    if (token == null || token.isEmpty) return;

    final scheme = _client.baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = _client.baseUrl.replaceFirst('https://', '').replaceFirst('http://', '');
    final uri = Uri.parse('$scheme://$host/ws/chats/$threadId?token=$token');
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _connectedThreadId = threadId;
      channel.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] == 'message') {
              _appendMessage(
                threadId,
                VendorChatMessage(
                  id: msg['id'] as String? ?? 'ws_${DateTime.now().microsecondsSinceEpoch}',
                  senderId: msg['sender_id'] as String? ?? '',
                  content: msg['content'] as String?,
                  imageUrl: msg['image_url'] as String?,
                  isRead: true,
                  createdAt: DateTime.tryParse(msg['created_at'] as String? ?? '')
                          ?.toLocal() ??
                      DateTime.now(),
                ),
              );
            }
          } catch (_) {}
        },
        onError: (_) {
          _connectedThreadId = null;
          notifyListeners();
        },
        onDone: () {
          _connectedThreadId = null;
          notifyListeners();
        },
      );
    } catch (_) {
      // Offline — history still shows; sends surface an error.
      _connectedThreadId = null;
    }
  }

  Future<void> _closeSocket() async {
    await _channel?.sink.close();
    _channel = null;
    _connectedThreadId = null;
  }

  /// Call when leaving a chat screen.
  Future<void> disconnect() {
    if (_openChats > 0) _openChats--;
    return _closeSocket();
  }

  void sendMessage(String threadId, String content) {
    if (content.trim().isEmpty) return;
    final thread = threadById(threadId);
    if (thread == null) return;

    if (_connectedThreadId != threadId || _channel == null) {
      lastError = 'Chat is offline. Check your connection and reopen the chat.';
      notifyListeners();
      return;
    }

    _channel!.sink.add(jsonEncode({'content': content.trim()}));
    final message = VendorChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      senderId: _myUserId,
      content: content.trim(),
      isRead: true,
      createdAt: DateTime.now(),
    );
    thread.messages.add(message);
    // Update the thread-list preview immediately so the chat list is
    // correct without waiting for a refetch.
    thread.notePreview(message);
    notifyListeners();
  }

  void _appendMessage(String threadId, VendorChatMessage message) {
    final thread = threadById(threadId);
    if (thread == null) return;
    // Skip echoes of my own optimistic bubble (same content within 10s).
    if (message.fromMe(_myUserId)) {
      final hasSimilar = thread.messages.any((m) =>
          m.fromMe(_myUserId) &&
          m.content == message.content &&
          DateTime.now().difference(m.createdAt).inSeconds < 10);
      if (hasSimilar) return;
    }
    thread.messages.add(message);
    // A message arriving over the socket updates the preview right away so
    // the list reflects it before the next thread-list fetch.
    thread.notePreview(message);
    notifyListeners();
  }
}
