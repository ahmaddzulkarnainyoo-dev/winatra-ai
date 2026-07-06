import 'package:flutter/material.dart';
import '../providers/robot_state_provider.dart';
import 'ai_service.dart';
import 'rag_service.dart';

/// Service to handle robot interactions from anywhere in the app.
/// Provides methods to update robot expression based on AI state.
class RobotInteractionService {
  static final RobotInteractionService _instance = RobotInteractionService._internal();
  factory RobotInteractionService() => _instance;
  RobotInteractionService._internal();

  RobotStateProvider? _stateProvider;

  /// Initialize with a reference to RobotStateProvider
  void init(RobotStateProvider provider) {
    _stateProvider = provider;
  }

  /// Called when AI starts processing a query
  void onAIProcessing() {
    _stateProvider?.onAIProcessing();
  }

  /// Called when AI finishes processing
  void onAIComplete() {
    _stateProvider?.onAIComplete();
  }

  /// Called when a new chat message is received
  void onNewMessage() {
    _stateProvider?.onNewMessage();
  }

  /// Show a greeting speech bubble
  void showGreeting() {
    _stateProvider?.showSpeechBubble('Ada yang bisa dibantu?');
  }

  /// Show a custom speech bubble
  void showSpeechBubble(String text) {
    _stateProvider?.showSpeechBubble(text);
  }

  /// Hide speech bubble
  void hideSpeechBubble() {
    _stateProvider?.hideSpeechBubble();
  }

  /// Toggle robot visibility
  void toggleVisibility() {
    if (_stateProvider != null) {
      _stateProvider!.setVisibility(!_stateProvider!.isVisible);
    }
  }

  /// Set robot visibility
  void setVisibility(bool visible) {
    _stateProvider?.setVisibility(visible);
  }

  /// Handle a natural language query from the robot tap
  Future<String> handleQuery(String query) async {
    onAIProcessing();
    try {
      // Search The Brain for context
      String context = '';
      try {
        context = await RAGService.searchAllDocuments(query);
      } catch (_) {}

      // Generate AI answer
      final aiService = AIService();
      final answer = await aiService.generateAnswer(
        query: query,
        isOffline: false,
        context: context,
      );

      onAIComplete();
      return answer.isEmpty ? 'Maaf, tidak dapat menjawab saat ini.' : answer;
    } catch (e) {
      onAIComplete();
      return 'Error: ${e.toString()}';
    }
  }
}