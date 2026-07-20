import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../../../core/models/chat_message_model.dart';
import '../../../core/theme/app_colors.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRegenerate;

  const ChatBubble({
    super.key,
    required this.message,
    this.onEdit,
    this.onDelete,
    this.onRegenerate,
  });

  bool get isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isUser
        ? (isDark ? AppColors.bubbleUserDark : AppColors.bubbleUserLight)
        : (isDark ? AppColors.bubbleAiDark : AppColors.bubbleAiLight);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isError ? AppColors.error.withValues(alpha: 0.15) : bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: message.isError
                    ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
                    : null,
              ),
              child: message.attachmentType != AttachmentType.none && isUser
                  ? _buildAttachmentPreview(context)
                  : _buildContent(context),
            ),
            if (message.isStreaming)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 4),
                child: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
              ),
            if (!message.isStreaming && message.content.isNotEmpty)
              _buildActionsRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(message.attachmentType), size: 18),
            const SizedBox(width: 6),
            Text(_labelFor(message.attachmentType), style: const TextStyle(fontSize: 12.5)),
          ],
        ),
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message.content),
        ],
      ],
    );
  }

  IconData _iconFor(AttachmentType t) {
    switch (t) {
      case AttachmentType.image: return Icons.image_outlined;
      case AttachmentType.audio: return Icons.audiotrack_outlined;
      case AttachmentType.pdf: return Icons.picture_as_pdf_outlined;
      case AttachmentType.docx: return Icons.description_outlined;
      case AttachmentType.csv: return Icons.table_chart_outlined;
      case AttachmentType.json: return Icons.data_object_outlined;
      case AttachmentType.zip: return Icons.folder_zip_outlined;
      default: return Icons.attach_file;
    }
  }

  String _labelFor(AttachmentType t) => 'Lampiran: ${t.name.toUpperCase()}';

  Widget _buildContent(BuildContext context) {
    if (message.content.isEmpty) {
      return const SizedBox(height: 6, width: 6);
    }
    // Split by fenced code blocks and render each segment appropriately,
    // so we get real syntax highlighting instead of markdown's plain block.
    final segments = _splitCodeBlocks(message.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: segments.map((seg) {
        if (seg.isCode) {
          return _CodeBlock(code: seg.text, language: seg.language);
        }
        return MarkdownBody(
          data: seg.text,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 2, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionIcon(
            icon: Icons.copy_rounded,
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Disalin ke clipboard'), duration: Duration(seconds: 1)),
              );
            },
          ),
          if (isUser && onEdit != null)
            _ActionIcon(icon: Icons.edit_outlined, onTap: onEdit!),
          if (onDelete != null)
            _ActionIcon(icon: Icons.delete_outline, onTap: onDelete!),
          if (!isUser && onRegenerate != null)
            _ActionIcon(icon: Icons.refresh_rounded, onTap: onRegenerate!),
        ],
      ),
    );
  }

  List<_Segment> _splitCodeBlocks(String text) {
    final result = <_Segment>[];
    final pattern = RegExp(r'```(\w*)\n([\s\S]*?)```');
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        result.add(_Segment(text.substring(last, match.start), false, ''));
      }
      result.add(_Segment(match.group(2) ?? '', true, match.group(1) ?? ''));
      last = match.end;
    }
    if (last < text.length) {
      result.add(_Segment(text.substring(last), false, ''));
    }
    if (result.isEmpty) result.add(_Segment(text, false, ''));
    return result;
  }
}

class _Segment {
  final String text;
  final bool isCode;
  final String language;
  _Segment(this.text, this.isCode, this.language);
}

class _CodeBlock extends StatelessWidget {
  final String code;
  final String language;
  const _CodeBlock({required this.code, required this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(language.isEmpty ? 'code' : language,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: code)),
                  child: const Icon(Icons.copy, size: 16, color: Colors.white54),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: HighlightView(
              code,
              language: language.isEmpty ? 'plaintext' : language,
              theme: atomOneDarkTheme,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
