import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  // Captured for dispose(), where inherited lookups are no longer allowed.
  late final ChatProvider _chat = context.read<ChatProvider>();

  @override
  void initState() {
    super.initState();
    // Loads history + opens the live WebSocket channel for this thread.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chat.connect(widget.threadId);
    });
  }

  @override
  void dispose() {
    // Leave the WS channel when the screen closes.
    _chat.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _chat.sendMessage(widget.threadId, content: text);
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

  /// Picks a photo, uploads it to /uploads, then sends its URL over chat.
  Future<void> _sendImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (picked == null || !mounted) return;
      final url = await _chat.uploadImage(picked.path);
      if (!mounted) return;
      _chat.sendMessage(widget.threadId, imageUrl: url);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not send the photo — try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final thread = chatProvider.threadById(widget.threadId);
    if (thread == null) {
      return const Scaffold(body: Center(child: Text('Conversation not found')));
    }

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
                      final isMe = m.fromMe;
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
                              if (m.imageUrl != null && m.imageUrl!.startsWith('http'))
                                GestureDetector(
                                  onTap: () => showDialog(
                                    context: context,
                                    builder: (_) => Dialog(
                                      child: InteractiveViewer(
                                        child: Image.network(m.imageUrl!),
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    child: Image.network(
                                      m.imageUrl!,
                                      width: 160,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 160,
                                        height: 120,
                                        color: Colors.black12,
                                        child: Icon(Icons.image,
                                            color: isMe ? Colors.white70 : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
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
