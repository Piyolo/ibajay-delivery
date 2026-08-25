import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';

class _ChatPreview {
  final String customerName;
  final String orderId;
  final String lastMessage;
  final String time;
  final bool unread;
  const _ChatPreview({
    required this.customerName,
    required this.orderId,
    required this.lastMessage,
    required this.time,
    this.unread = false,
  });
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  static const _chats = [
    _ChatPreview(
      customerName: 'Juan Dela Cruz',
      orderId: 'ORD-1042',
      lastMessage: 'Is it okay if I add extra rice?',
      time: '2m',
      unread: true,
    ),
    _ChatPreview(
      customerName: 'Angela Reyes',
      orderId: 'ORD-1041',
      lastMessage: 'Thank you! On my way to pick up.',
      time: '18m',
    ),
    _ChatPreview(
      customerName: 'Mark Villanueva',
      orderId: 'ORD-1040',
      lastMessage: 'You: Rider is 5 minutes away.',
      time: '40m',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, i) {
          final chat = _chats[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                chat.customerName[0],
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(chat.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${chat.orderId} · ${chat.lastMessage}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chat.unread ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: chat.unread ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chat.time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (chat.unread) ...[
                  const SizedBox(height: 6),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                ],
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(customerName: chat.customerName, orderId: chat.orderId),
              ),
            ),
          );
        },
      ),
    );
  }
}
