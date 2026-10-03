import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';
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

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final threads = chat.threads;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: RefreshIndicator(
        onRefresh: () => context.read<ChatProvider>().loadThreads(),
        child: chat.isLoading && threads.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : threads.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.forum_outlined,
                          size: 48, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          chat.lastError ?? 'No conversations yet',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: OutlinedButton(
                          onPressed: () => context.read<ChatProvider>().loadThreads(),
                          // The theme's minimumSize is width-infinite
                          // (full-width form buttons); cap it here so the
                          // button hugs its label instead of the screen.
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(140, 44),
                            maximumSize: const Size.fromWidth(200),
                          ),
                          child: const Text('Refresh'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: threads.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, i) {
                      final thread = threads[i];
                      final last = thread.messages.isNotEmpty ? thread.messages.last : null;
                      final unread = last != null && !last.isRead && !last.fromMe(chat.myUserId);
                      final preview = last?.content ?? 'No messages yet';
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            thread.customerName.isNotEmpty
                                ? thread.customerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(thread.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (last != null)
                              Text(_timeAgo(last.createdAt),
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary)),
                            if (unread) ...[
                              const SizedBox(height: 6),
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppColors.primary, shape: BoxShape.circle)),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(threadId: thread.id),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
