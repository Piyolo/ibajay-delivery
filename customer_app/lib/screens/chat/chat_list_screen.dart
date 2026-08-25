import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final threads = context.watch<ChatProvider>().threads;

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: threads.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No conversations yet',
              subtitle: 'Message a vendor from their store page to start chatting.',
            )
          : ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = threads[i];
                final last = t.lastMessage;
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceMuted,
                    child: Icon(Icons.storefront, color: AppColors.textSecondary),
                  ),
                  title: Text(t.vendorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    last?.content ?? (last?.imageUrl != null ? '📷 Photo' : 'Say hello!'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (last != null)
                        Text(DateFormat.Hm().format(last.createdAt),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      if (t.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: AppColors.primary,
                          child: Text('${t.unreadCount}',
                              style: const TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    context.read<ChatProvider>().markThreadRead(t.id);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(threadId: t.id)));
                  },
                );
              },
            ),
    );
  }
}
