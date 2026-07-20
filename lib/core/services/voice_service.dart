import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// Wraps Speech-To-Text and Text-To-Speech so the rest of the app never
/// touches the plugins directly.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool get isListening => _speech.isListening;

  Future<bool> initSpeech() async {
    if (_sttReady) return true;
    _sttReady = await _speech.initialize(
      onError: (e) => print('STT error: $e'),
      onStatus: (s) => print('STT status: $s'),
    );
    return _sttReady;
  }

  /// Starts listening and streams partial + final transcriptions.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'id_ID',
  }) async {
    final ready = await initSpeech();
    if (!ready) return;
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      partialResults: true,
      cancelOnError: true,
    );
  }

  Future<void> stopListening() => _speech.stop();

  Future<void> speak(String text) async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.speak(_stripMarkdown(text));
  }

  Future<void> stopSpeaking() => _tts.stop();

  /// TTS shouldn't read raw markdown symbols out loud.
  String _stripMarkdown(String input) {
    return input
        .replaceAll(RegExp(r'[*_`#>~-]'), '')
        .replaceAll(RegExp(r'\n{2,}'), '. ');
  }
}
