import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String threadId;
  const ChatScreen({super.key, required this.threadId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatProvider>().sendMessage(widget.threadId, content: text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendImage() {
    // Placeholder for image_picker integration — attaches a stand-in URL for now.
    context.read<ChatProvider>().sendMessage(widget.threadId, imageUrl: 'local_asset://demo_photo.png');
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final thread = chatProvider.threads.firstWhere((t) => t.id == widget.threadId);

    return Scaffold(
      appBar: AppBar(title: Text(thread.vendorName)),
      body: Column(
        children: [
          Expanded(
            child: thread.messages.isEmpty
                ? const Center(
                    child: Text('Say hello to start the conversation', style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: thread.messages.length,
                    itemBuilder: (context, i) {
                      final m = thread.messages[i];
                      final isMe = m.senderId == 'me';
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.imageUrl != null)
                                Container(
                                  width: 160,
                                  height: 120,
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(Icons.image, color: isMe ? Colors.white70 : AppColors.textSecondary),
                                ),
                              if (m.content != null)
                                Text(
                                  m.content!,
                                  style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.Hm().format(m.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Type a message...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
