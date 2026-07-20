import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String text, String? attachmentPath) onSend;
  final bool isGenerating;
  final VoidCallback onStop;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.isGenerating,
    required this.onStop,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  String? _attachmentPath;
  bool _isListening = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'zip', 'csv', 'json', 'png', 'jpg', 'jpeg', 'mp3', 'wav', 'm4a'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _attachmentPath = result.files.single.path);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file != null) setState(() => _attachmentPath = file.path);
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await VoiceService.instance.stopListening();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await VoiceService.instance.startListening(
      onResult: (text, isFinal) {
        setState(() => _controller.text = text);
        if (isFinal) setState(() => _isListening = false);
      },
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachmentPath == null) return;
    widget.onSend(text, _attachmentPath);
    _controller.clear();
    setState(() => _attachmentPath = null);
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Galeri'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File (PDF, DOCX, TXT, ZIP, CSV, JSON, Audio)'),
              onTap: () { Navigator.pop(context); _pickFile(); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachmentPath != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(_attachmentPath!.split('/').last, overflow: TextOverflow.ellipsis),
                  onDeleted: () => setState(() => _attachmentPath = null),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _showAttachMenu,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Mendengarkan...' : 'Tanyakan apa saja ke GHANZ AI...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none_outlined,
                      color: _isListening ? AppColors.neonPurple : null),
                  onPressed: _toggleMic,
                ),
                widget.isGenerating
                    ? IconButton(
                        icon: const Icon(Icons.stop_circle_outlined, color: AppColors.error),
                        onPressed: widget.onStop,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.neonGradient,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                          onPressed: _send,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
