import 'dart:io';
import '../models/chat_message_model.dart';

class FileExtractionService {
  FileExtractionService._();
  static final FileExtractionService instance = FileExtractionService._();

  AttachmentType detectType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'webp':
        return AttachmentType.image;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
        return AttachmentType.audio;
      case 'pdf':
        return AttachmentType.pdf;
      case 'docx':
        return AttachmentType.docx;
      case 'txt':
        return AttachmentType.txt;
      case 'zip':
        return AttachmentType.zip;
      case 'csv':
        return AttachmentType.csv;
      case 'json':
        return AttachmentType.json;
      default:
        return AttachmentType.other;
    }
  }

  /// For plain-text-like formats we read a capped preview directly so we
  /// can send it as inline text to Gemini (more reliable than binary for
  /// CSV/JSON/TXT). Returns null for binary formats (image/audio/pdf/docx/zip),
  /// which are instead sent as base64 inline_data by GeminiService.
  Future<String?> readTextPreview(String path, {int maxChars = 20000}) async {
    final type = detectType(path);
    if (type != AttachmentType.txt &&
        type != AttachmentType.csv &&
        type != AttachmentType.json) {
      return null;
    }
    final file = File(path);
    final content = await file.readAsString();
    if (content.length <= maxChars) return content;
    return '${content.substring(0, maxChars)}\n\n[...dipotong, file terlalu panjang...]';
  }

  String humanFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
