import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onenm_local_llm/onenm_local_llm.dart';
import 'remote_config_service.dart';

/// Unified AI service that works both online (DeepSeek API) and offline (local LLM).
class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  OneNm? _localAI;
  bool _isLocalInitialized = false;
  String _localStatus = 'Not initialized';

  /// Get current local AI status message
  String get localStatus => _localStatus;

  /// Whether local AI is ready
  bool get isLocalReady => _isLocalInitialized;

  /// Initialize local LLM (offline mode)
  Future<void> initLocal({OneNmProgressCallback? onProgress}) async {
    if (_isLocalInitialized) return;

    try {
      _localStatus = 'Memeriksa model...';
      onProgress?.call(_localStatus);

      // Use Qwen2.5 1.5B — more capable than TinyLlama
      _localAI = OneNm(
        model: OneNmModel.qwen25,
        settings: const GenerationSettings(
          temperature: 0.7,
          maxTokens: 512,
          topK: 40,
          topP: 0.9,
          repeatPenalty: 1.1,
        ),
        onProgress: (status) {
          _localStatus = status;
          onProgress?.call(status);
        },
      );

      _localStatus = 'Memuat model...';
      onProgress?.call(_localStatus);
      await _localAI!.initialize();

      _localStatus = 'Model siap!';
      _isLocalInitialized = true;
      onProgress?.call(_localStatus);
    } catch (e) {
      _localStatus = 'Gagal memuat model: $e';
      _isLocalInitialized = false;
      rethrow;
    }
  }

  /// Send a message to AI (online or offline based on [isOffline])
  Future<String> chat({
    required String message,
    required bool isOffline,
    String? systemPrompt,
  }) async {
    if (isOffline) {
      return _chatLocal(message, systemPrompt: systemPrompt);
    } else {
      return _chatOnline(message, systemPrompt: systemPrompt);
    }
  }

  /// Generate answer with context from The Brain (for keyboard/notification services)
  /// This method automatically searches all documents in The Brain for relevant context.
  Future<String> generateAnswer({
    required String query,
    required bool isOffline,
    String context = '',
  }) async {
    final systemPrompt = context.isNotEmpty
        ? '''Kamu adalah Winatra AI, asisten belajar yang membantu dan ramah.
JAWABLAH DALAM BAHASA INDONESIA.
Gunakan konteks berikut untuk menjawab pertanyaan:

$context

Berikan jawaban yang jelas, informatif, dan mudah dipahami.
Jangan mengulangi perintah atau instruksi dalam jawabanmu.
Jawab langsung pertanyaannya tanpa basa-basi.'''
        : null;

    return await chat(
      message: query,
      isOffline: isOffline,
      systemPrompt: systemPrompt,
    );
  }

  /// Chat using local LLM
  Future<String> _chatLocal(String message, {String? systemPrompt}) async {
    if (!_isLocalInitialized || _localAI == null) {
      throw Exception('Model lokal belum siap. Silakan tunggu atau gunakan mode online.');
    }

    final systemMsg = systemPrompt ?? _buildLocalSystemPrompt();
    final reply = await _localAI!.chat(message, systemPrompt: systemMsg);
    return reply;
  }

  /// Build a good system prompt for local model
  String _buildLocalSystemPrompt() {
    return '''Kamu adalah Winatra AI, asisten belajar yang membantu dan ramah.
JAWABLAH DALAM BAHASA INDONESIA.
Berikan jawaban yang jelas, informatif, dan mudah dipahami.
Jika ditanya tentang suatu konsep, jelaskan dengan detail minimal 3-4 kalimat.
Jangan mengulangi perintah atau instruksi dalam jawabanmu.
Jawab langsung pertanyaannya tanpa basa-basi.''' ;
  }

  /// Chat using DeepSeek API (online)
  Future<String> _chatOnline(String message, {String? systemPrompt}) async {
    try {
      final remoteConfig = RemoteConfigService();
      // Fallback: Remote Config dulu, lalu hardcoded key user sebagai cadangan
      final apiKey = remoteConfig.getDeepSeekPrimary().isNotEmpty
          ? remoteConfig.getDeepSeekPrimary()
          : 'sk-3f82fc1304a1486b99ae94d4bb9b59b4'; // Hardcoded fallback
      
      if (apiKey.isEmpty) {
        throw Exception('API key tidak tersedia. Periksa koneksi internet atau hubungi admin.');
      }

      final systemMsg = systemPrompt ?? _buildOnlineSystemPrompt();

      // Gunakan API key dari hardcoded jika Remote Config tidak tersedia
      final effectiveApiKey = apiKey.isNotEmpty ? apiKey : 'sk-3f82fc1304a1486b99ae94d4bb9b59b4';

      final response = await http.post(
        Uri.parse('https://api.deepseek.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $effectiveApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': [
            {'role': 'system', 'content': systemMsg},
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        return content.toString().trim();
      } else {
        throw Exception('DeepSeek API error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // Return friendly error message instead of crashing
      return 'Maaf, saya tidak bisa menjawab saat ini. Error: $e';
    }
  }

  String _buildOnlineSystemPrompt() {
    return '''Kamu adalah Winatra AI, asisten belajar yang membantu dan ramah.
JAWABLAH DALAM BAHASA INDONESIA.
Berikan jawaban yang jelas, informatif, dan mudah dipahami.
Jika ditanya tentang suatu konsep, jelaskan dengan detail.
Jangan mengulangi perintah atau instruksi dalam jawabanmu.
Jawab langsung pertanyaannya.''' ;
  }

  /// Clear local conversation history
  void clearLocalHistory() {
    _localAI?.clearHistory();
  }

  /// Dispose local AI resources
  Future<void> disposeLocal() async {
    try {
      await _localAI?.dispose();
    } catch (_) {}
    _localAI = null;
    _isLocalInitialized = false;
    _localStatus = 'Disposed';
  }
}