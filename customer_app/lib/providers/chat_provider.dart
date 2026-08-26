import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/chat.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';
import '../services/preferences_service.dart';

/// Real chat against /chats/* with live delivery over
/// `ws://.../ws/chats/{id}?token=<access>`.
///
/// Sending goes through the open WebSocket (the backend persists incoming
/// WS messages); history loads over REST when a thread opens.
class ChatProvider extends ChangeNotifier {
  ChatProvider({ApiClient? apiClient}) : _client = apiClient ?? ApiClient();

  final ApiClient _client;

  final List<ChatThread> _threads = [];
  // Threads currently open in memory (id -> thread), so a list refresh
  // never wipes live messages.
  final Map<String, ChatThread> _openThreads = {};
  WebSocketChannel? _channel;
  String? _connectedThreadId;
  bool _isLoading = false;
  String? lastError;
  String _myUserId = 'me';
  bool get isLoading => _isLoading;

  List<ChatThread> get threads => List.unmodifiable(_threads);

  ChatThread? threadById(String id) {
    try {
      return _threads.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Finds an in-memory thread carrying live messages for [vendorId].
  ChatThread? openThreadForVendor(String vendorId) => _openThreads[vendorId];

  /// Uploads a photo and returns its public URL (POST /uploads).
  Future<String> uploadImage(String filePath) async {
    final result = await _client.postMultipart('/uploads', filePath: filePath)
        as Map<String, dynamic>;
    return result['url'] as String;
  }

  Future<void> _cacheSessionUser() async {
    final json = await PreferencesService.getString(PreferencesService.kSessionUser);
    if (json != null) {
      try {
        final user = jsonDecode(json) as Map<String, dynamic>;
        if (user['id'] != null) _myUserId = user['id'] as String;
      } catch (_) {}
    }
  }

  /// Pulls the customer's chat threads (chat list screen). The server
  /// returns one row per thread; rows are de-duplicated per vendor so a
  /// legacy duplicate never shows twice.
  Future<void> loadThreads() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _cacheSessionUser();
      final rows = await _client.get('/chats/my') as List<dynamic>;
      final parsed = rows.map((r) => _threadFromApi(r as Map<String, dynamic>)).toList();

      final byVendor = <String, ChatThread>{};
      for (final t in parsed) {
        final existing = byVendor[t.vendorId];
        if (existing == null) {
          byVendor[t.vendorId] = t;
        } else {
          // Keep whichever thread actually has the conversation.
          final existingCount = existing.messages.isNotEmpty
              ? existing.messages.length
              : existing.messageCount;
          final newCount =
              t.messages.isNotEmpty ? t.messages.length : t.messageCount;
          if (newCount > existingCount) byVendor[t.vendorId] = t;
        }
      }
      // Carry over any in-memory messages from already-open threads.
      _threads
        ..clear()
        ..addAll(byVendor.values.map((t) {
          final open = _openThreads[t.vendorId];
          if (open != null && open.messages.isNotEmpty) {
            t.messages.addAll(open.messages);
          }
          return t;
        }));
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Opens (or creates) the thread with [vendor], loads its history and
  /// connects the live channel. Replaces the old mock getOrCreateThread.
  Future<ChatThread> getOrCreateThread(VendorProfile vendor, {String? orderId}) async {
    await _cacheSessionUser();

    ChatThread thread;
    try {
      final json = await _client.post('/chats', body: {
        'vendor_id': vendor.id,
        if (orderId != null) 'order_id': orderId,
      }) as Map<String, dynamic>;
      thread = _threadFromApi(json, fallbackVendorName: vendor.storeName);
    } on ApiException catch (e) {
      lastError = e.message;
      // Offline fallback: keep an ephemeral local thread so the screen
      // still opens; messages will queue visually but not persist.
      thread = ChatThread(
        id: 'local_${vendor.id}',
        vendorId: vendor.id,
        vendorName: vendor.storeName,
        vendorLogoUrl: vendor.logoUrl,
        orderId: orderId,
      );
    }

    final existing = threadById(thread.id);
    if (existing != null) {
      // Preserve any live messages already loaded for this thread.
      if (thread.messages.isNotEmpty) {
        existing.messages
          ..clear()
          ..addAll(thread.messages);
        existing.lastMessageText = thread.lastMessageText;
        existing.messageCount = thread.messageCount;
      }
      notifyListeners();
      await connect(existing.id);
      return existing;
    }

    _openThreads[thread.vendorId] = thread;
    _threads.insert(0, thread);
    notifyListeners();
    await connect(thread.id);
    return thread;
  }

  /// Loads full history and opens the live WebSocket for [threadId].
  Future<void> connect(String threadId) async {
    await _cacheSessionUser();
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
        ..addAll(rows.map((r) => ChatMessage.fromApi(r as Map<String, dynamic>, myUserId: _myUserId)));
      notifyListeners();
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<void> _openSocket(String threadId) async {
    await _closeSocket();
    final token = await PreferencesService.getString(PreferencesService.kAccessToken);
    if (token == null) return;

    final base = _client.baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$base/ws/chats/$threadId?token=$token');
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
                ChatMessage(
                  id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
                  senderId: msg['sender_id'] as String? ?? '',
                  content: msg['content'] as String?,
                  imageUrl: msg['image_url'] as String?,
                  createdAt: DateTime.tryParse(msg['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
                  fromMe: msg['sender_id'] == _myUserId,
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
      // WS unavailable (offline / server asleep) — sends will fail with a
      // surfaced error; history still shows.
      _connectedThreadId = null;
    }
  }

  Future<void> _closeSocket() async {
    await _channel?.sink.close();
    _channel = null;
    _connectedThreadId = null;
  }

  /// Call when leaving the chat screen.
  Future<void> disconnect() => _closeSocket();

  void sendMessage(String threadId, {String? content, String? imageUrl}) {
    final thread = threadById(threadId);
    if (thread == null) return;

    if (_connectedThreadId != threadId || _channel == null) {
      lastError = 'Chat is offline. Check your connection and reopen the chat.';
      notifyListeners();
      return;
    }

    // Optimistic bubble; the WS broadcast for my own message is ignored
    // (matched by content+recency is unreliable — the backend echoes to
    // the sender too, so dedupe by ignoring the next echo of same sender).
    _channel!.sink.add(jsonEncode({
      if (content != null) 'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
    }));
    thread.messages.add(ChatMessage(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      senderId: _myUserId,
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: true,
      fromMe: true,
    ));
    notifyListeners();
  }

  void _appendMessage(String threadId, ChatMessage message) {
    final thread = threadById(threadId);
    if (thread == null) return;
    // Skip echoes of my own optimistic bubble (same sender + content).
    if (message.fromMe) {
      final hasSimilar = thread.messages.any((m) =>
          m.fromMe &&
          m.content == message.content &&
          DateTime.now().difference(m.createdAt).inSeconds < 10);
      if (hasSimilar) return;
    }
    thread.messages.add(message);
    notifyListeners();
  }

  void markThreadRead(String threadId) {
    final thread = threadById(threadId);
    if (thread == null) return;
    final myId = _myUserId;
    for (final m in thread.messages) {
      if (m.senderId != myId) m.isRead = true;
    }
    notifyListeners();
  }

  ChatThread _threadFromApi(Map<String, dynamic> json, {String? fallbackVendorName}) {
    return ChatThread(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      vendorName: json['vendor_name'] as String? ?? fallbackVendorName ?? 'Store',
      vendorLogoUrl: json['vendor_logo_url'] as String? ?? '',
      orderId: json['order_id'] as String?,
      lastMessageText: json['last_message'] as String?,
      lastMessageAt:
          DateTime.tryParse(json['last_message_at'] as String? ?? '')?.toLocal(),
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      messages: [
        for (final m in (json['messages'] as List?) ?? [])
          ChatMessage.fromApi(m as Map<String, dynamic>, myUserId: _myUserId),
      ],
    );
  }
}
