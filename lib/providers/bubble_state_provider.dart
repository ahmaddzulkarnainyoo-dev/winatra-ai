import 'package:flutter/foundation.dart';
import '../widgets/robot_character.dart' show RobotExpression;

/// State management for the Floating Chat Bubble (Robot).
/// This is SEPARATE from AssistantActiveProvider (voice assistant).
/// Controls:
/// - Whether the bubble is visible
/// - Robot expression on the bubble
/// - Drag position persistence
class BubbleStateProvider extends ChangeNotifier {
  static const String _prefKeyVisible = 'bubble_visible';

  bool _isVisible = true;
  RobotExpression _expression = RobotExpression.happy;
  bool _isIdle = true;

  bool get isVisible => _isVisible;
  RobotExpression get expression => _expression;
  bool get isIdle => _isIdle;

  /// Toggle bubble visibility
  void setVisible(bool value) {
    if (_isVisible == value) return;
    _isVisible = value;
    notifyListeners();
  }

  /// Set robot expression with auto-revert to happy after timeout
  void setExpression(RobotExpression exp, {bool autoRevert = false}) {
    _expression = exp;
    _isIdle = exp == RobotExpression.happy || exp == RobotExpression.idle;
    notifyListeners();

    if (autoRevert && exp != RobotExpression.happy) {
      Future.delayed(const Duration(seconds: 5), () {
        if (_expression == exp) {
          _expression = RobotExpression.happy;
          _isIdle = true;
          notifyListeners();
        }
      });
    }
  }

  /// Set robot to thinking state (for AI processing)
  void setThinking() {
    setExpression(RobotExpression.thinking);
  }

  /// Set robot to excited state (answer received)
  void setExcited() {
    setExpression(RobotExpression.excited, autoRevert: true);
  }

  /// Set robot to sleepy after long inactivity
  void setSleepy() {
    setExpression(RobotExpression.sleepy);
  }

  /// Reset to happy/idle
  void resetToHappy() {
    setExpression(RobotExpression.happy);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}