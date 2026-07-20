import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/chat_controller.dart';
import '../../core/models/chat_session_model.dart';
import '../../repository/chat_repository.dart';

class HistoryPage extends StatefulWidget {
  final void Function(String sessionId) onSelectSession;
  const HistoryPage({super.key, required this.onSelectSession});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = ChatRepository.instance;
  String _query = '';

  List<ChatSessionModel> get _sessions =>
      _query.isEmpty ? _repo.getAllSessions() : _repo.searchSessions(_query);

  Future<void> _rename(ChatSessionModel session) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ganti Nama Chat'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _repo.renameSession(session.id, result);
      setState(() {});
    }
  }

  Future<void> _delete(ChatSessionModel session) async {
    await _repo.deleteSession(session.id);
    setState(() {});
  }

  Future<void> _export(ChatSessionModel session) async {
    final path = await _repo.exportSessionToFile(session.id);
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result?.files.single.path == null) return;
    await _repo.importSessionFromFile(result!.files.single.path!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Chat'),
        actions: [
          IconButton(icon: const Icon(Icons.file_upload_outlined), onPressed: _import, tooltip: 'Import'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari riwayat chat...',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? const Center(child: Text('Belum ada riwayat chat.'))
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, i) {
                      final s = sessions[i];
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_formatDate(s.updatedAt)),
                        onTap: () {
                          context.read<ChatController>().loadSession(s.id);
                          widget.onSelectSession(s.id);
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') _rename(s);
                            if (value == 'delete') _delete(s);
                            if (value == 'export') _export(s);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Rename')),
                            PopupMenuItem(value: 'export', child: Text('Export')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
