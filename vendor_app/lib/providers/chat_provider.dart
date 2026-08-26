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
  final String customerName;
  final String? orderId;
  final List<VendorChatMessage> messages;

  VendorChatThread({
    required this.id,
    required this.customerName,
    this.orderId,
    List<VendorChatMessage>? messages,
  }) : messages = messages ?? [];
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

  bool get isLoading => _isLoading;
  List<VendorChatThread> get threads => List.unmodifiable(_threads);

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

  /// Pulls the store's chat threads.
  Future<void> loadThreads() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cacheMyUserId();
      final rows = await _client.get('/chats/vendor') as List<dynamic>;
      _threads
        ..clear()
        ..addAll(rows.map((r) {
          final m = r as Map<String, dynamic>;
          return VendorChatThread(
            id: m['id'] as String,
            customerName: m['customer_name'] as String? ?? 'Customer',
            orderId: m['order_id'] as String?,
          );
        }));
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Loads history and opens the live socket for [threadId].
  Future<void> connect(String threadId) async {
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
  Future<void> disconnect() => _closeSocket();

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
    thread.messages.add(VendorChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      senderId: _myUserId,
      content: content.trim(),
      isRead: true,
      createdAt: DateTime.now(),
    ));
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
    notifyListeners();
  }
}
