import 'package:flutter/material.dart';
import '../core/models/chat_message_model.dart';
import '../core/services/device_control_service.dart';
import '../core/services/gemini_service.dart';
import '../core/services/intent_classifier_service.dart';
import '../repository/chat_repository.dart';

class ChatController extends ChangeNotifier {
  final ChatRepository _repo = ChatRepository.instance;
  final GeminiService _gemini = GeminiService.instance;
  final IntentClassifierService _classifier = IntentClassifierService.instance;
  final DeviceControlService _device = DeviceControlService.instance;

  String? currentSessionId;
  List<ChatMessageModel> messages = [];
  bool isGenerating = false;
  String? errorMessage;

  static const String _systemInstruction = '''
Kamu adalah GHANZ AI, asisten AI serba bisa (gabungan ChatGPT, Google Assistant, dan Gemini)
yang berjalan di dalam aplikasi Android bernama GHANZ AI. Kamu membantu dengan pertanyaan umum,
coding di semua bahasa pemrograman, membuat website/aplikasi, menerjemahkan, merangkum,
menjelaskan materi, memperbaiki error, menganalisis gambar/dokumen/audio, dan banyak lagi.
Jawab dengan jelas, ringkas namun lengkap, gunakan Markdown dan code block dengan bahasa yang sesuai
untuk kode. Jawab dalam bahasa yang sama dengan pertanyaan pengguna.
''';

  Future<void> loadSession(String sessionId) async {
    currentSessionId = sessionId;
    messages = await _repo.getMessages(sessionId);
    notifyListeners();
  }

  Future<void> startNewSession() async {
    final session = await _repo.createSession();
    currentSessionId = session.id;
    messages = [];
    notifyListeners();
  }

  List<Map<String, dynamic>> _buildHistory() {
    return messages
        .where((m) => !m.isError)
        .map((m) => {
              'role': m.role == MessageRole.ai ? 'model' : 'user',
              'parts': [
                {'text': m.content}
              ],
            })
        .toList();
  }

  /// Main entry point: routes a user message to either a device action
  /// or Gemini, exactly as described in the "Smart AI" spec.
  Future<void> sendMessage(String text, {String? attachmentPath}) async {
    if (currentSessionId == null) await startNewSession();
    final sessionId = currentSessionId!;

    final attachmentType = attachmentPath != null
        ? _detectAttachment(attachmentPath)
        : AttachmentType.none;

    final userMsg = await _repo.addMessage(
      sessionId: sessionId,
      content: text,
      role: MessageRole.user,
      attachmentType: attachmentType,
      attachmentPath: attachmentPath,
    );
    messages.add(userMsg);
    notifyListeners();

    // 1) Try to classify as a device command first (only when no attachment,
    // since a message with a file attached is always meant for the AI).
    if (attachmentPath == null) {
      final classified = _classifier.classify(text);
      if (classified.intent != DeviceIntent.none) {
        await _executeDeviceIntent(sessionId, classified);
        return;
      }
    }

    // 2) Otherwise, send to Gemini (with streaming).
    await _sendToGemini(sessionId, text, attachmentPath: attachmentPath);
  }

  AttachmentType _detectAttachment(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'png': AttachmentType.image,
      'jpg': AttachmentType.image,
      'jpeg': AttachmentType.image,
      'webp': AttachmentType.image,
      'mp3': AttachmentType.audio,
      'wav': AttachmentType.audio,
      'm4a': AttachmentType.audio,
      'pdf': AttachmentType.pdf,
      'docx': AttachmentType.docx,
      'txt': AttachmentType.txt,
      'zip': AttachmentType.zip,
      'csv': AttachmentType.csv,
      'json': AttachmentType.json,
    };
    return map[ext] ?? AttachmentType.other;
  }

  Future<void> _executeDeviceIntent(String sessionId, ClassifiedIntent c) async {
    DeviceActionResult result;
    switch (c.intent) {
      case DeviceIntent.setAlarm:
        result = await _device.setAlarm(c.params['hour'], c.params['minute']);
        break;
      case DeviceIntent.flashlightOn:
        result = await _device.flashlightOn(autoOffAfterSeconds: c.params['seconds']);
        break;
      case DeviceIntent.flashlightOff:
        result = await _device.flashlightOff();
        break;
      case DeviceIntent.openWhatsApp:
        result = await _device.openPackage('com.whatsapp', 'WhatsApp');
        break;
      case DeviceIntent.openTelegram:
        result = await _device.openPackage('org.telegram.messenger', 'Telegram');
        break;
      case DeviceIntent.openInstagram:
        result = await _device.openPackage('com.instagram.android', 'Instagram');
        break;
      case DeviceIntent.openTikTok:
        result = await _device.openPackage('com.zhiliaoapp.musically', 'TikTok');
        break;
      case DeviceIntent.openYoutube:
        result = await _device.openPackage('com.google.android.youtube', 'YouTube');
        break;
      case DeviceIntent.openCamera:
        result = await _device.openCamera();
        break;
      case DeviceIntent.openGallery:
        result = await _device.openGallery();
        break;
      case DeviceIntent.openMaps:
        result = await _device.openPackage('com.google.android.apps.maps', 'Google Maps');
        break;
      case DeviceIntent.openChrome:
        result = await _device.openPackage('com.android.chrome', 'Chrome');
        break;
      case DeviceIntent.volumeUp:
        result = await _device.adjustVolume(up: true);
        break;
      case DeviceIntent.volumeDown:
        result = await _device.adjustVolume(up: false);
        break;
      case DeviceIntent.silentMode:
        result = await _device.requestSilentMode();
        break;
      case DeviceIntent.vibrate:
        result = await _device.vibrate(c.params['seconds'] ?? 2);
        break;
      case DeviceIntent.setBrightness:
        result = await _device.setBrightness(c.params['percent'] ?? 50);
        break;
      case DeviceIntent.callContact:
        result = await _device.callNumber(c.params['name'] ?? '');
        break;
      case DeviceIntent.sendSms:
        result = await _device.openSms();
        break;
      case DeviceIntent.openEmail:
        result = await _device.openEmail();
        break;
      case DeviceIntent.shareFile:
        result = await _device.shareText('Dibagikan dari GHANZ AI');
        break;
      default:
        result = DeviceActionResult(false, 'Perintah belum didukung.');
    }

    final aiMsg = await _repo.addMessage(
      sessionId: sessionId,
      content: result.message,
      role: MessageRole.ai,
    );
    if (!result.success) aiMsg.isError = true;
    messages.add(aiMsg);
    notifyListeners();
  }

  Future<void> _sendToGemini(String sessionId, String text, {String? attachmentPath}) async {
    isGenerating = true;
    errorMessage = null;
    final aiMsg = await _repo.addMessage(
      sessionId: sessionId,
      content: '',
      role: MessageRole.ai,
    );
    aiMsg.isStreaming = true;
    messages.add(aiMsg);
    notifyListeners();

    try {
      final parts = <GeminiPart>[GeminiPart.text(text)];
      if (attachmentPath != null) {
        parts.add(await _gemini.filePartFromPath(attachmentPath));
      }

      final history = _buildHistory()
        ..removeWhere((h) => h['parts'][0]['text'] == '' );
      // Remove the just-added empty AI placeholder & the just-added user msg
      // from history since they're passed separately as `parts`.
      if (history.isNotEmpty) history.removeLast();
      if (history.isNotEmpty) history.removeLast();

      final buffer = StringBuffer();
      await for (final chunk in _gemini.generateContentStream(
        history: history,
        parts: parts,
        systemInstruction: _systemInstruction,
      )) {
        buffer.write(chunk);
        aiMsg.content = buffer.toString();
        notifyListeners();
      }

      if (buffer.isEmpty) {
        aiMsg.content = 'Maaf, tidak ada respons dari AI. Coba lagi.';
        aiMsg.isError = true;
      }
    } catch (e) {
      aiMsg.content = e.toString().replaceFirst('GeminiException: ', '');
      aiMsg.isError = true;
      errorMessage = aiMsg.content;
    } finally {
      aiMsg.isStreaming = false;
      await _repo.updateMessageContent(sessionId, aiMsg.id, aiMsg.content);
      isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> regenerateLast() async {
    if (messages.length < 2) return;
    final lastUser = messages.reversed.firstWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => messages.first,
    );
    // Remove trailing AI message(s) after the last user message.
    final idx = messages.indexOf(lastUser);
    final toRemove = messages.sublist(idx + 1);
    for (final m in toRemove) {
      await _repo.deleteMessage(currentSessionId!, m.id);
    }
    messages = messages.sublist(0, idx + 1);
    notifyListeners();
    await _sendToGemini(currentSessionId!, lastUser.content,
        attachmentPath: lastUser.attachmentPath);
  }

  Future<void> deleteMessage(ChatMessageModel msg) async {
    await _repo.deleteMessage(currentSessionId!, msg.id);
    messages.remove(msg);
    notifyListeners();
  }

  Future<void> editMessage(ChatMessageModel msg, String newContent) async {
    msg.content = newContent;
    await _repo.updateMessageContent(currentSessionId!, msg.id, newContent);
    notifyListeners();
  }

  void stopGenerating() {
    // Streaming is cooperative; flipping the flag stops further UI updates
    // from awaiting the next chunk in practice once combined with a
    // cancel token in GeminiService for a production build.
    isGenerating = false;
    notifyListeners();
  }
}
