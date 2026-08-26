import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatProvider>().loadThreads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final threads = chat.threads;

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: chat.isLoading && threads.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => chat.loadThreads(),
              child: threads.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: 'No conversations yet',
                          subtitle:
                              'Message a vendor from their store page to start chatting.',
                        ),
                      ],
                    )
                  : ListView.separated(
                       itemCount: threads.length,
                       separatorBuilder: (_, __) => const Divider(height: 1),
                       itemBuilder: (context, i) {
                         final t = threads[i];
                         final last = t.lastMessage;
                         final preview = t.previewText ??
                             (last?.imageUrl != null || t.messageCount > 0
                                 ? '📷 Photo'
                                 : 'Say hello!');
                         final time = t.previewTime;
                         return ListTile(
                           leading: CircleAvatar(
                             backgroundColor: AppColors.surfaceMuted,
                             backgroundImage: t.vendorLogoUrl.startsWith('http')
                                 ? NetworkImage(t.vendorLogoUrl)
                                 : null,
                             child: t.vendorLogoUrl.startsWith('http')
                                 ? null
                                 : const Icon(Icons.storefront, color: AppColors.textSecondary),
                           ),
                           title: Text(t.vendorName,
                               style: const TextStyle(fontWeight: FontWeight.w700)),
                           subtitle: Text(
                             preview,
                             maxLines: 1,
                             overflow: TextOverflow.ellipsis,
                             style: TextStyle(
                               color: last != null && !last.isRead && !last.fromMe
                                   ? AppColors.textPrimary
                                   : AppColors.textSecondary,
                             ),
                           ),
                           trailing: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                               if (time != null)
                                 Text(DateFormat('MMM d, h:mm a').format(time),
                                     style: const TextStyle(
                                         fontSize: 11, color: AppColors.textSecondary)),
                               if (t.unreadCount > 0) ...[
                                 const SizedBox(height: 4),
                                 CircleAvatar(
                                   radius: 9,
                                   backgroundColor: AppColors.primary,
                                   child: Text('${t.unreadCount}',
                                       style:
                                           const TextStyle(fontSize: 10, color: Colors.white)),
                                 ),
                               ],
                             ],
                           ),
                           onTap: () {
                             chat.markThreadRead(t.id);
                             Navigator.of(context).push(
                               MaterialPageRoute(builder: (_) => ChatScreen(threadId: t.id)),
                             );
                           },
                         );
                       },
                     ),
            ),
    );
  }
}
