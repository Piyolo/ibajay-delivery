import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/vendor.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatThread> _threads = [];

  List<ChatThread> get threads => List.unmodifiable(_threads);

  ChatThread getOrCreateThread(VendorProfile vendor, {String? orderId}) {
    try {
      return _threads.firstWhere((t) => t.vendorId == vendor.id && t.orderId == orderId);
    } catch (_) {
      final thread = ChatThread(
        id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
        vendorId: vendor.id,
        vendorName: vendor.storeName,
        vendorLogoUrl: vendor.logoUrl,
        orderId: orderId,
      );
      _threads.add(thread);
      notifyListeners();
      return thread;
    }
  }

  void sendMessage(String threadId, {String? content, String? imageUrl}) {
    final thread = _threads.firstWhere((t) => t.id == threadId);
    thread.messages.add(ChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      senderId: 'me',
      content: content,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: true,
    ));
    notifyListeners();

    // Demo auto-reply so the chat screen feels alive before the backend/WS is wired in.
    Future.delayed(const Duration(seconds: 2), () {
      thread.messages.add(ChatMessage(
        id: 'm_${DateTime.now().microsecondsSinceEpoch}_r',
        senderId: thread.vendorId,
        content: "Thanks for your message! We'll get back to you shortly.",
        createdAt: DateTime.now(),
      ));
      notifyListeners();
    });
  }

  void markThreadRead(String threadId) {
    final thread = _threads.firstWhere((t) => t.id == threadId);
    for (final m in thread.messages) {
      m.isRead = true;
    }
    notifyListeners();
  }
}
