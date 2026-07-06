import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service for voice input (STT via native Android SpeechRecognizer)
/// and voice output (TTS via flutter_tts).
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  static const MethodChannel _speechChannel = MethodChannel('winatra/speech');

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
  void Function(String error)? onError;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  /// Initialize TTS and set up MethodChannel listener for native STT
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Set up MethodChannel handler for native speech events
      _speechChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onListeningStarted':
            _isListening = true;
            onListeningStarted?.call();
            break;
          case 'onListeningStopped':
            _isListening = false;
            onListeningStopped?.call();
            break;
          case 'onPartialResult':
            final text = call.arguments as String? ?? '';
            onPartialResult?.call(text);
            break;
          case 'onFinalResult':
            final text = call.arguments as String? ?? '';
            _isListening = false;
            onFinalResult?.call(text);
            break;
          case 'onVolumeChanged':
            final volume = (call.arguments as num?)?.toDouble() ?? 0.0;
            onVolumeChanged?.call(volume);
            break;
          case 'onError':
            final error = call.arguments as String? ?? 'Unknown error';
            _isListening = false;
            onError?.call(error);
            onListeningStopped?.call();
            break;
        }
        return null;
      });

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

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('VoiceService: Initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening via native Android SpeechRecognizer
  Future<void> startListening() async {
    if (_isListening) return;

    try {
      await _speechChannel.invokeMethod('startListening');
      // The native side will call onListeningStarted via MethodChannel
    } catch (e) {
      debugPrint('VoiceService: startListening error: $e');
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechChannel.invokeMethod('stopListening');
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
      await _speechChannel.invokeMethod('cancelListening');
      _isListening = false;
      onListeningStopped?.call();
    } catch (e) {
      debugPrint('VoiceService: cancelListening error: $e');
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  /// Speak text via TTS
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

  /// Stop speaking
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

  /// Check if TTS is available
  Future<bool> get isTTSAvailable async =>
      await _tts.isLanguageAvailable('id-ID');

  /// Dispose resources
  Future<void> dispose() async {
    if (_isListening) {
      await _speechChannel.invokeMethod('stopListening');
    }
    if (_isSpeaking) {
      await _tts.stop();
    }
    _isInitialized = false;
    _isListening = false;
    _isSpeaking = false;
  }
}