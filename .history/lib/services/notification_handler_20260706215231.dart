import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rag_service.dart';
import 'ai_service.dart';

/// Handler for MethodChannel communication between native Android services
/// (WinatraService, WinatraKeyboardService) and Flutter (Dart).
///
/// The native side calls these methods via FlutterBridge:
/// - "getAnswer" → Returns AI answer with context from The Brain
/// - "getBrainContext" → Returns context from The Brain only
class NotificationHandler {
  static const _channel = MethodChannel('winatra/bridge');
  static bool _isSetup = false;

  /// Setup the MethodChannel handler.
  /// Must be called once after Firebase.initializeApp().
  static void setup() {
    if (_isSetup) return;
    _isSetup = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'getAnswer':
          return _handleGetAnswer(call.arguments?.toString() ?? '');
        case 'getBrainContext':
          return _handleGetBrainContext(call.arguments?.toString() ?? '');
        default:
          print('NotificationHandler: Method ${call.method} not implemented');
          return null;
      }
    });

    print('NotificationHandler: MethodChannel handler set up successfully');
  }

  /// Handle "getAnswer" - search The Brain for context, then generate AI answer
  static Future<String> _handleGetAnswer(String query) async {
    if (query.isEmpty) {
      print('NotificationHandler: Empty query received');
      return 'Error: Empty query';
    }

    // Check authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('NotificationHandler: User not authenticated');
      return 'Error: Silakan login terlebih dahulu.';
    }

    print('NotificationHandler: Handling query: "${query.substring(0, query.length > 50 ? 50 : query.length)}..."');

    try {
      // Step 1: Search The Brain for relevant context
      String context = '';
      try {
        context = await RAGService.searchAllDocuments(query);
        print('NotificationHandler: Got context (${context.length} chars) from The Brain');
      } catch (e) {
        print('NotificationHandler: Error searching The Brain: $e');
        // Continue without context
      }

      // Step 2: Generate AI answer with context
      final aiService = AIService();
      String answer;

      if (context.isNotEmpty) {
        // Use generateAnswer which incorporates context into system prompt
        answer = await aiService.generateAnswer(
          query: query,
          isOffline: false,
          context: context,
        );
        print('NotificationHandler: Answer generated WITH The Brain context');
      } else {
        // No context found, just use regular chat
        answer = await aiService.chat(
          message: query,
          isOffline: false,
          systemPrompt: '''Kamu adalah Winatra AI, asisten belajar yang membantu dan ramah.
JAWABLAH DALAM BAHASA INDONESIA.
Berikan jawaban yang jelas, informatif, dan mudah dipahami.
Jangan mengulangi perintah atau instruksi dalam jawabanmu.
Jawab langsung pertanyaannya tanpa basa-basi.''',
        );
        print('NotificationHandler: Answer generated WITHOUT The Brain context');
      }

      // Format the answer nicely
      final formattedAnswer = answer.isEmpty
          ? 'Maaf, tidak dapat menghasilkan jawaban saat ini.'
          : answer;

      print('NotificationHandler: Returning answer (${formattedAnswer.length} chars)');
      return formattedAnswer;
    } catch (e) {
      print('NotificationHandler: Error generating answer: $e');
      return 'Error: ${e.toString()}';
    }
  }

  /// Handle "getBrainContext" - search The Brain for relevant context
  static Future<String> _handleGetBrainContext(String query) async {
    if (query.isEmpty) {
      print('NotificationHandler: Empty query for brain context');
      return '';
    }

    try {
      final context = await RAGService.searchAllDocuments(query);
      print('NotificationHandler: Returning context (${context.length} chars) for query');
      return context;
    } catch (e) {
      print('NotificationHandler: Error getting brain context: $e');
      return '';
    }
  }
}