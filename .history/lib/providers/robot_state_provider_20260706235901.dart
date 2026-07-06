import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/robot_character.dart' show RobotExpression;

/// State management for the floating robot character.
/// Controls expression, visibility, and interaction state.
class RobotStateProvider extends ChangeNotifier {
  RobotExpression _expression = RobotExpression.happy;
  bool _isVisible = true;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _showSpeechBubble = false;
  String _speechText = '';
  bool _isIdle = true;

  RobotExpression get expression => _expression;
  bool get isVisible => _isVisible;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  bool get showSpeechBubble => _showSpeechBubble;
  String get speechText => _speechText;
  bool get isIdle => _isIdle;

  /// Update robot expression
  void updateExpression(RobotExpression newExpression) {
    if (_expression != newExpression) {
      _expression = newExpression;
      _isIdle = false;
      notifyListeners();
    }
  }

  /// Show/hide the robot
  void setVisibility(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }

  /// Set processing state (AI is thinking)
  void setProcessing(bool processing) {
    if (_isProcessing != processing) {
      _isProcessing = processing;
      if (processing) {
        updateExpression(RobotExpression.thinking);
      }
      notifyListeners();
    }
  }

  /// Set listening state (STT active)
  void setListening(bool listening) {
    if (_isListening != listening) {
      _isListening = listening;
      if (listening) {
        updateExpression(RobotExpression.listening);
      }
      notifyListeners();
    }
  }

  /// Set speaking state (TTS active)
  void setSpeaking(bool speaking) {
    if (_isSpeaking != speaking) {
      _isSpeaking = speaking;
      if (speaking) {
        updateExpression(RobotExpression.speaking);
      }
      notifyListeners();
    }
  }

  /// Show a speech bubble with text
  void displaySpeechBubble(String text) {
    _showSpeechBubble = true;
    _speechText = text;
    updateExpression(RobotExpression.excited);
    notifyListeners();

    // Auto-hide after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_showSpeechBubble) {
        hideSpeechBubble();
      }
    });
  }

  /// Hide speech bubble
  void hideSpeechBubble() {
    _showSpeechBubble = false;
    _speechText = '';
    _isIdle = true;
    _isListening = false;
    _isSpeaking = false;
    _isProcessing = false;
    updateExpression(RobotExpression.happy);
    notifyListeners();
  }

  /// Set error state
  void setError() {
    updateExpression(RobotExpression.error);
    _isIdle = false;
    notifyListeners();

    // Auto-recover after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_expression == RobotExpression.error) {
        _isIdle = true;
        updateExpression(RobotExpression.happy);
        notifyListeners();
      }
    });
  }

  /// Set the robot to idle/waiting for wake word
  void setWaiting() {
    updateExpression(RobotExpression.waiting);
    _isIdle = false;
    notifyListeners();
  }

  /// Called when AI starts processing
  void onAIProcessing() {
    setProcessing(true);
  }

  /// Called when AI finishes processing
  void onAIComplete() {
    _isProcessing = false;
    _isSpeaking = false;
    _isListening = false;
    _isIdle = true;
    updateExpression(RobotExpression.happy);
    notifyListeners();
  }

  /// Called when there's a new chat message
  void onNewMessage() {
    updateExpression(RobotExpression.excited);
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isProcessing && !_isSpeaking && !_isListening) {
        _isIdle = true;
        updateExpression(RobotExpression.happy);
        notifyListeners();
      }
    });
  }

  /// Start idle animation - random expression changes every 5 seconds
  void startIdleAnimation() {
    _isIdle = true;
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isIdle || !_isVisible) return;

      final expressions = RobotExpression.values;
      final randomExpression = expressions[math.Random().nextInt(expressions.length)];

      // Only change if not processing, not listening, not speaking and not showing speech bubble
      if (!_isProcessing && !_isListening && !_isSpeaking && !_showSpeechBubble) {
        _expression = randomExpression;
        notifyListeners();
      }
    });
  }
}