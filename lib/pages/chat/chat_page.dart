import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_controller.dart';
import '../../core/models/chat_message_model.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;
  const ChatPage({super.key, required this.onOpenDrawer});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: widget.onOpenDrawer),
        title: ShaderMask(
          shaderCallback: (b) => AppColors.neonGradient.createShader(b),
          child: const Text('GHANZ AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Chat Baru',
            onPressed: () => context.read<ChatController>().startNewSession(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? _buildEmptyState(context)
                : NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) => true,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (context, i) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                        final msg = chat.messages[i];
                        return ChatBubble(
                          message: msg,
                          onDelete: () => chat.deleteMessage(msg),
                          onEdit: msg.role == MessageRole.user
                              ? () => _showEditDialog(context, chat, msg)
                              : null,
                          onRegenerate: msg.role == MessageRole.ai && i == chat.messages.length - 1
                              ? () => chat.regenerateLast()
                              : null,
                        );
                      },
                    ),
                  ),
          ),
          ChatInputBar(
            isGenerating: chat.isGenerating,
            onStop: () => chat.stopGenerating(),
            onSend: (text, attachment) => chat.sendMessage(text, attachmentPath: attachment),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final suggestions = [
      'Buatkan fungsi Flutter untuk validasi email',
      'Setel alarm jam 07:00',
      'Rangkum artikel yang aku kirim',
      'Nyalakan senter selama 5 detik',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.neonGradient.createShader(b),
              child: const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text('Ada yang bisa GHANZ AI bantu?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 12.5)),
                        onPressed: () => context.read<ChatController>().sendMessage(s),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChatController chat, ChatMessageModel msg) {
    final controller = TextEditingController(text: msg.content);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Pesan'),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              chat.editMessage(msg, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
