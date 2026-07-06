import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// Service for voice input (STT) and voice output (TTS).
/// Wraps speech_to_text and flutter_tts packages.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  // Callbacks
  VoidCallback? onListeningStarted;
  VoidCallback? onListeningStopped;
  void Function(String text)? onPartialResult;
  void Function(String text)? onFinalResult;
  VoidCallback? onSpeakingStarted;
  VoidCallback? onSpeakingStopped;
  void Function(double volume)? onVolumeChanged;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  /// Initialize both STT and TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize STT
      final sttAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('VoiceService: STT error: $error');
        },
        onStatus: (status) {
          debugPrint('VoiceService: STT status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStopped?.call();
          }
        },
      );

      // Initialize TTS
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakingStarted?.call();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingStopped?.call();
      });

      _tts.setErrorHandler((error) {
        debugPrint('VoiceService: TTS error: $error');
        _isSpeaking = false;
        onSpeakingStopped?.call();
      });

      _isInitialized = sttAvailable;
      return sttAvailable;
    } catch (e) {
      debugPrint('VoiceService: Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening (STT)
  Future<void> startListening() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (_isListening) return;

    try {
      _isListening = true;
      onListeningStarted?.call();

      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          if (result.finalResult) {
            onFinalResult?.call(text);
          } else {
            onPartialResult?.call(text);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        localeId: 'id_ID',
        listenMode: stt.ListenMode.dictation,
        onSoundLevelChange: (level) {
          onVolumeChanged?.call(level);
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('VoiceService: startListening error: $e');
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Stop listening (STT)
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      onListeningStopped?.call();
    } catch (e) {
      debugPrint('VoiceService: stopListening error: $e');
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Cancel listening without getting result
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speech.cancel();
      _isListening = false;
      onListeningStopped?.call();
    } catch (e) {
      debugPrint('VoiceService: cancelListening error: $e');
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Speak text (TTS)
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    if (text.isEmpty) return;

    try {
      _isSpeaking = true;
      onSpeakingStarted?.call();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('VoiceService: speak error: $e');
      _isSpeaking = false;
      onSpeakingStopped?.call();
    }
  }

  /// Stop speaking (TTS)
  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;

    try {
      await _tts.stop();
      _isSpeaking = false;
      onSpeakingStopped?.call();
    } catch (e) {
      debugPrint('VoiceService: stopSpeaking error: $e');
      _isSpeaking = false;
      onSpeakingStopped?.call();
    }
  }

  /// Check if the device supports STT
  bool get isSTTAvailable => _speech.isAvailable;

  /// Check if the device supports TTS
  Future<bool> get isTTSAvailable async => await _tts.isLanguageAvailable('id-ID');

  /// Dispose resources
  Future<void> dispose() async {
    if (_isListening) {
      await _speech.stop();
    }
    if (_isSpeaking) {
      await _tts.stop();
    }
    _isInitialized = false;
    _isListening = false;
    _isSpeaking = false;
  }
}