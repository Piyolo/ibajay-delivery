import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class _Message {
  final String text;
  final bool fromVendor;
  final String time;
  const _Message({required this.text, required this.fromVendor, required this.time});
}

/// Order-based chat between vendor and customer.
/// TODO: replace the in-memory `_messages` list with a FastAPI WebSocket
/// connection (e.g. `ws://.../ws/chats/{orderId}`) for real-time delivery,
/// and persist history via the `chats`/`messages` tables.
class ChatScreen extends StatefulWidget {
  final String customerName;
  final String orderId;
  const ChatScreen({super.key, required this.customerName, required this.orderId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<_Message> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      const _Message(text: 'Hi! I just placed an order.', fromVendor: false, time: '2:41 PM'),
      const _Message(text: 'Got it, preparing it now 😊', fromVendor: true, time: '2:42 PM'),
      const _Message(text: 'Is it okay if I add extra rice?', fromVendor: false, time: '2:44 PM'),
    ];
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(text: text, fromVendor: true, time: 'Now'));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(widget.orderId, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _messages.length,
                itemBuilder: (context, i) => _bubble(_messages[i]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Type a message…'),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Message m) {
    final align = m.fromVendor ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = m.fromVendor ? AppColors.primary : AppColors.surfaceMuted;
    final textColor = m.fromVendor ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(m.text, style: TextStyle(color: textColor)),
          ),
          const SizedBox(height: 2),
          Text(m.time, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
