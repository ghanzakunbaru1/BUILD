import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../utils/constants.dart';

/// A single part of multimodal content sent to Gemini.
class GeminiPart {
  final String? text;
  final String? mimeType;
  final String? base64Data;

  GeminiPart.text(this.text)
      : mimeType = null,
        base64Data = null;

  GeminiPart.inlineData({required this.mimeType, required this.base64Data})
      : text = null;

  Map<String, dynamic> toJson() {
    if (text != null) return {'text': text};
    return {
      'inline_data': {'mime_type': mimeType, 'data': base64Data},
    };
  }
}

/// Thrown when the Gemini API returns an error or the request fails.
class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

class GeminiService {
  GeminiService._internal();
  static final GeminiService instance = GeminiService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 3),
  ));

  /// Runtime override for API key (set from Settings > "Ganti API Key").
  String? _overrideKey;

  void setApiKeyOverride(String? key) {
    _overrideKey = (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  String get _apiKey {
    final key = _overrideKey ?? dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty || key == 'YOUR_GEMINI_API_KEY') {
      throw GeminiException(
        'API Key Gemini belum diatur. Buka Settings > Ganti API Key, '
        'atau isi GEMINI_API_KEY di file .env.',
      );
    }
    return key;
  }

  /// Sends a multimodal message to Gemini and returns the full text response.
  ///
  /// [history] is the prior conversation as a list of
  /// {'role': 'user'|'model', 'parts': [...]} maps, oldest first.
  Future<String> generateContent({
    required List<Map<String, dynamic>> history,
    required List<GeminiPart> parts,
    String? systemInstruction,
  }) async {
    final url = '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent';

    final contents = [
      ...history,
      {
        'role': 'user',
        'parts': parts.map((p) => p.toJson()).toList(),
      },
    ];

    final body = {
      'contents': contents,
      if (systemInstruction != null)
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'maxOutputTokens': 4096,
      },
    };

    try {
      final response = await _dio.post(
        url,
        queryParameters: {'key': _apiKey},
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: jsonEncode(body),
      );

      final data = response.data;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw GeminiException('Gemini tidak mengembalikan respons. Coba lagi.');
      }
      final content = candidates.first['content'];
      final partsOut = content['parts'] as List?;
      if (partsOut == null || partsOut.isEmpty) {
        throw GeminiException('Respons Gemini kosong.');
      }
      final buffer = StringBuffer();
      for (final p in partsOut) {
        if (p['text'] != null) buffer.write(p['text']);
      }
      return buffer.toString();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error']?['message'] ?? e.message)
          : e.message;
      throw GeminiException('Gagal menghubungi Gemini: $msg');
    }
  }

  /// Streams the response using Server-Sent-Events (streamGenerateContent).
  /// Yields incremental text chunks as they arrive.
  Stream<String> generateContentStream({
    required List<Map<String, dynamic>> history,
    required List<GeminiPart> parts,
    String? systemInstruction,
  }) async* {
    final url =
        '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:streamGenerateContent';

    final contents = [
      ...history,
      {
        'role': 'user',
        'parts': parts.map((p) => p.toJson()).toList(),
      },
    ];

    final body = {
      'contents': contents,
      if (systemInstruction != null)
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
        'maxOutputTokens': 4096,
      },
    };

    try {
      final response = await _dio.post<ResponseBody>(
        url,
        queryParameters: {'key': _apiKey, 'alt': 'sse'},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          responseType: ResponseType.stream,
        ),
        data: jsonEncode(body),
      );

      final stream = response.data!.stream;
      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        final raw = buffer.toString();
        final lines = raw.split('\n');
        // Keep the last (possibly incomplete) line in the buffer.
        buffer
          ..clear()
          ..write(lines.isNotEmpty ? lines.last : '');

        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('data:')) continue;
          final jsonStr = line.substring(5).trim();
          if (jsonStr.isEmpty) continue;
          try {
            final decoded = jsonDecode(jsonStr);
            final candidates = decoded['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) continue;
            final contentParts = candidates.first['content']?['parts'] as List?;
            if (contentParts == null) continue;
            for (final p in contentParts) {
              if (p['text'] != null) yield p['text'] as String;
            }
          } catch (_) {
            // Ignore partial/non-JSON keep-alive lines.
          }
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error']?['message'] ?? e.message)
          : e.message;
      throw GeminiException('Gagal menghubungi Gemini: $msg');
    }
  }

  /// Reads a local file and converts it to a base64 inline_data part,
  /// picking the correct MIME type from the extension.
  Future<GeminiPart> filePartFromPath(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final ext = path.split('.').last.toLowerCase();
    final mime = _mimeFor(ext);
    return GeminiPart.inlineData(mimeType: mime, base64Data: base64Encode(bytes));
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
