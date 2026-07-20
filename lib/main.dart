import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/models/chat_message_model.dart';
import 'core/models/chat_session_model.dart';
import 'repository/chat_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load API key from .env (never hardcoded, per spec).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not found — app still runs; GeminiService will prompt the user
    // to set a key via Settings > Ganti API Key.
  }

  // Local storage (Hive) for unlimited chat history.
  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageModelAdapter());
  Hive.registerAdapter(MessageRoleAdapter());
  Hive.registerAdapter(AttachmentTypeAdapter());
  Hive.registerAdapter(ChatSessionModelAdapter());
  await ChatRepository.instance.init();

  runApp(const GhanzApp());
}
