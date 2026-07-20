import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/models/chat_message_model.dart';
import '../core/models/chat_session_model.dart';
import '../utils/constants.dart';

/// Data-access layer for chat history. UI/controllers never touch Hive
/// directly — everything goes through here (Clean Architecture boundary).
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  static const _uuid = Uuid();

  late Box<ChatSessionModel> _sessionBox;
  final Map<String, Box<ChatMessageModel>> _messageBoxes = {};

  Future<void> init() async {
    _sessionBox = await Hive.openBox<ChatSessionModel>(AppConstants.chatBox);
  }

  Future<Box<ChatMessageModel>> _messageBox(String sessionId) async {
    if (_messageBoxes.containsKey(sessionId)) return _messageBoxes[sessionId]!;
    final box = await Hive.openBox<ChatMessageModel>(
        '${AppConstants.messageBoxPrefix}$sessionId');
    _messageBoxes[sessionId] = box;
    return box;
  }

  // ---------------- Sessions ----------------

  List<ChatSessionModel> getAllSessions() {
    final list = _sessionBox.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<ChatSessionModel> createSession({String? title}) async {
    final now = DateTime.now();
    final session = ChatSessionModel(
      id: _uuid.v4(),
      title: title ?? 'Chat Baru',
      createdAt: now,
      updatedAt: now,
    );
    await _sessionBox.put(session.id, session);
    return session;
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    final session = _sessionBox.get(sessionId);
    if (session == null) return;
    session.title = newTitle;
    session.updatedAt = DateTime.now();
    await session.save();
  }

  Future<void> touchSession(String sessionId) async {
    final session = _sessionBox.get(sessionId);
    if (session == null) return;
    session.updatedAt = DateTime.now();
    await session.save();
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessionBox.delete(sessionId);
    final box = await _messageBox(sessionId);
    await box.clear();
    await box.deleteFromDisk();
    _messageBoxes.remove(sessionId);
  }

  Future<void> deleteAllSessions() async {
    for (final session in _sessionBox.values.toList()) {
      await deleteSession(session.id);
    }
  }

  List<ChatSessionModel> searchSessions(String query) {
    final q = query.toLowerCase();
    return getAllSessions().where((s) => s.title.toLowerCase().contains(q)).toList();
  }

  // ---------------- Messages ----------------

  Future<List<ChatMessageModel>> getMessages(String sessionId) async {
    final box = await _messageBox(sessionId);
    final list = box.values.toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  Future<ChatMessageModel> addMessage({
    required String sessionId,
    required String content,
    required MessageRole role,
    AttachmentType attachmentType = AttachmentType.none,
    String? attachmentPath,
  }) async {
    final box = await _messageBox(sessionId);
    final message = ChatMessageModel(
      id: _uuid.v4(),
      sessionId: sessionId,
      content: content,
      role: role,
      timestamp: DateTime.now(),
      attachmentType: attachmentType,
      attachmentPath: attachmentPath,
    );
    await box.put(message.id, message);
    await touchSession(sessionId);
    return message;
  }

  Future<void> updateMessageContent(
      String sessionId, String messageId, String newContent) async {
    final box = await _messageBox(sessionId);
    final msg = box.get(messageId);
    if (msg == null) return;
    msg.content = newContent;
    await msg.save();
  }

  Future<void> deleteMessage(String sessionId, String messageId) async {
    final box = await _messageBox(sessionId);
    await box.delete(messageId);
  }

  // ---------------- Export / Import ----------------

  Future<String> exportSessionToFile(String sessionId) async {
    final session = _sessionBox.get(sessionId);
    final messages = await getMessages(sessionId);
    final data = {
      'session': {
        'id': session?.id,
        'title': session?.title,
        'createdAt': session?.createdAt.toIso8601String(),
      },
      'messages': messages
          .map((m) => {
                'role': m.role.name,
                'content': m.content,
                'timestamp': m.timestamp.toIso8601String(),
                'attachmentType': m.attachmentType.name,
              })
          .toList(),
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ghanz_export_${session?.title ?? sessionId}.json');
    await file.writeAsString(jsonEncode(data), flush: true);
    return file.path;
  }

  Future<ChatSessionModel> importSessionFromFile(String path) async {
    final file = File(path);
    final raw = jsonDecode(await file.readAsString());
    final title = raw['session']?['title'] ?? 'Chat Import';
    final session = await createSession(title: 'Import: $title');
    final box = await _messageBox(session.id);
    for (final m in (raw['messages'] as List? ?? [])) {
      final role = MessageRole.values.firstWhere(
        (r) => r.name == m['role'],
        orElse: () => MessageRole.user,
      );
      final message = ChatMessageModel(
        id: _uuid.v4(),
        sessionId: session.id,
        content: m['content'] ?? '',
        role: role,
        timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
      );
      await box.put(message.id, message);
    }
    return session;
  }
}
