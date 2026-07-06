import 'package:flutter/foundation.dart';

/// State management for voice input (STT) and voice output (TTS).
/// Controls listening, speaking, and transcript state.
class VoiceProvider extends ChangeNotifier {
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isSTTInitialized = false;
  bool _isTTSInitialized = false;
  String _transcript = '';
  String _lastSpokenText = '';
  double _speechVolume = 0.0; // 0.0 to 1.0 for voice indicator animation

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isSTTInitialized => _isSTTInitialized;
  bool get isTTSInitialized => _isTTSInitialized;
  String get transcript => _transcript;
  String get lastSpokenText => _lastSpokenText;
  double get speechVolume => _speechVolume;

  /// Set STT initialization status
  void setSTTInitialized(bool value) {
    if (_isSTTInitialized != value) {
      _isSTTInitialized = value;
      notifyListeners();
    }
  }

  /// Set TTS initialization status
  void setTTSInitialized(bool value) {
    if (_isTTSInitialized != value) {
      _isTTSInitialized = value;
      notifyListeners();
    }
  }

  /// Set listening state (STT active)
  void setListening(bool value) {
    if (_isListening != value) {
      _isListening = value;
      if (!value) {
        _speechVolume = 0.0;
      }
      notifyListeners();
    }
  }

  /// Set speaking state (TTS active)
  void setSpeaking(bool value) {
    if (_isSpeaking != value) {
      _isSpeaking = value;
      if (!value) {
        _speechVolume = 0.0;
      }
      notifyListeners();
    }
  }

  /// Update speech volume level (for voice indicator animation)
  void setSpeechVolume(double volume) {
    _speechVolume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Set the recognized text from STT
  void setTranscript(String text) {
    _transcript = text;
    notifyListeners();
  }

  /// Clear transcript
  void clearTranscript() {
    _transcript = '';
    notifyListeners();
  }

  /// Record the last spoken text
  void setLastSpokenText(String text) {
    _lastSpokenText = text;
    notifyListeners();
  }

  /// Reset all voice states
  void reset() {
    _isListening = false;
    _isSpeaking = false;
    _transcript = '';
    _speechVolume = 0.0;
    notifyListeners();
  }
}