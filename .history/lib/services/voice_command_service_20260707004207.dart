import '../providers/robot_state_provider.dart';
import '../providers/voice_provider.dart';
import '../providers/assistant_state_provider.dart';
import 'voice_service.dart';

/// Orchestrates the voice command flow:
/// Wake word → STT → Parse → Execute → TTS → Expression sync
class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final VoiceService _voiceService = VoiceService();
  bool _isInitialized = false;
  bool _isProcessing = false;

  // References to providers (set during init)
  RobotStateProvider? _robotState;
  VoiceProvider? _voiceProvider;
  AssistantActiveProvider? _assistantProvider;

  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;

  /// Initialize with provider references
  void init({
    required RobotStateProvider robotState,
    required VoiceProvider voiceProvider,
    required AssistantActiveProvider assistantProvider,
  }) {
    _robotState = robotState;
    _voiceProvider = voiceProvider;
    _assistantProvider = assistantProvider;

    // Set up voice service callbacks
    _voiceService.onListeningStarted = _onListeningStarted;
    _voiceService.onListeningStopped = _onListeningStopped;
    _voiceService.onPartialResult = _onPartialResult;
    _voiceService.onFinalResult = _onFinalResult;
    _voiceService.onSpeakingStarted = _onSpeakingStarted;
    _voiceService.onSpeakingStopped = _onSpeakingStopped;
    _voiceService.onVolumeChanged = _onVolumeChanged;

    _isInitialized = true;
  }

  /// Start the voice assistant (called after wake word detected)
  Future<void> startVoiceInput() async {
    if (!_isInitialized || _isProcessing) return;

    _isProcessing = true;

    // Update robot expression to listening
    _robotState?.setListening(true);
    _voiceProvider?.setListening(true);

    // Speak prompt
    await _voiceService.speak('Ya, ada yang bisa dibantu?');

    // Small delay then start listening
    await Future.delayed(const Duration(milliseconds: 500));
    await _voiceService.startListening();
  }

  /// Process a voice command text
  Future<void> processCommand(String text) async {
    if (text.isEmpty) return;

    _isProcessing = true;
    _robotState?.setProcessing(true);
    _voiceProvider?.setTranscript(text);

    // Simple command parsing (will be enhanced with Python parser later)
    final command = text.toLowerCase().trim();

    String response;

    if (command.contains('buka') || command.contains('open')) {
      response = await _handleOpenCommand(command);
    } else if (command.contains('cari') || command.contains('search')) {
      response = await _handleSearchCommand(command);
    } else if (command.contains('balas') || command.contains('reply')) {
      response = await _handleReplyCommand(command);
    } else if (command.contains('baca') || command.contains('read')) {
      response = await _handleReadCommand(command);
    } else if (command.contains('siapa') || command.contains('apa') || command.contains('bagaimana')) {
      response = await _handleQuestionCommand(command);
    } else if (command.contains('halo') || command.contains('hai') || command.contains('hi')) {
      response = 'Halo! Ada yang bisa saya bantu?';
    } else if (command.contains('terima kasih') || command.contains('thanks') || command.contains('makasih')) {
      response = 'Sama-sama! Senang bisa membantu.';
    } else if (command.contains('sembunyikan') || command.contains('hide')) {
      await _assistantProvider?.hideRobot();
      response = 'Robot disembunyikan. Tap dua kali di pojok kanan bawah untuk menampilkan kembali.';
    } else if (command.contains('tampilkan') || command.contains('show')) {
      await _assistantProvider?.showRobot();
      response = 'Robot ditampilkan kembali.';
    } else {
      // Fallback: treat as question for AI
      response = await _handleQuestionCommand(command);
    }

    // Speak the response
    _robotState?.setSpeaking(true);
    _voiceProvider?.setSpeaking(true);
    _robotState?.displaySpeechBubble(response);
    _assistantProvider?.setLastActionResult(response);

    await _voiceService.speak(response);

    // Reset state
    _isProcessing = false;
    _robotState?.onAIComplete();
    _voiceProvider?.reset();
  }

  /// Handle "buka [app/website]" commands
  Future<String> _handleOpenCommand(String command) async {
    if (command.contains('whatsapp') || command.contains('wa')) {
      _assistantProvider?.setCurrentScreen('whatsapp');
      return 'Membuka WhatsApp...';
    } else if (command.contains('google')) {
      _assistantProvider?.setCurrentScreen('google');
      return 'Membuka Google...';
    } else if (command.contains('youtube') || command.contains('yt')) {
      _assistantProvider?.setCurrentScreen('youtube');
      return 'Membuka YouTube...';
    } else if (command.contains('instagram') || command.contains('ig')) {
      _assistantProvider?.setCurrentScreen('instagram');
      return 'Membuka Instagram...';
    } else if (command.contains('gmail') || command.contains('email')) {
      _assistantProvider?.setCurrentScreen('gmail');
      return 'Membuka Gmail...';
    } else if (command.contains('settings') || command.contains('pengaturan')) {
      _assistantProvider?.setCurrentScreen('settings');
      return 'Membuka Pengaturan...';
    } else {
      return 'Maaf, saya belum bisa membuka aplikasi tersebut. Silakan coba aplikasi lain.';
    }
  }

  /// Handle "cari [query]" commands
  Future<String> _handleSearchCommand(String command) async {
    final query = command
        .replaceAll(RegExp(r'cari|search|tentang|info'), '')
        .trim();
    if (query.isNotEmpty) {
      _assistantProvider?.setCurrentScreen('search');
      _assistantProvider?.setContext('last_search', query);
      return 'Mencari $query di Google...';
    }
    return 'Apa yang ingin Anda cari?';
  }

  /// Handle "balas [pesan]" commands
  Future<String> _handleReplyCommand(String command) async {
    // This would use AccessibilityService to reply
    return 'Fitur balas pesan akan segera tersedia.';
  }

  /// Handle "baca [notifikasi]" commands
  Future<String> _handleReadCommand(String command) async {
    // This would use AccessibilityService to read notifications
    return 'Fitur baca notifikasi akan segera tersedia.';
  }

  /// Handle question commands (send to AI)
  Future<String> _handleQuestionCommand(String command) async {
    // This would send to DeepSeek + The Brain via AIService
    // For now, return a placeholder
    _assistantProvider?.setCurrentScreen('ai_query');
    return 'Memproses pertanyaan Anda... Mohon tunggu sebentar.';
  }

  /// Cancel current voice operation
  Future<void> cancel() async {
    _isProcessing = false;
    await _voiceService.stopListening();
    await _voiceService.stopSpeaking();
    _robotState?.onAIComplete();
    _voiceProvider?.reset();
  }

  // ── Voice Service Callbacks ──

  void _onListeningStarted() {
    _robotState?.setListening(true);
    _voiceProvider?.setListening(true);
  }

  void _onListeningStopped() {
    _robotState?.setListening(false);
    _voiceProvider?.setListening(false);
  }

  void _onPartialResult(String text) {
    _voiceProvider?.setTranscript(text);
  }

  void _onFinalResult(String text) {
    _voiceProvider?.setTranscript(text);
    _voiceProvider?.setListening(false);
    _robotState?.setListening(false);

    // Process the command
    processCommand(text);
  }

  void _onSpeakingStarted() {
    _robotState?.setSpeaking(true);
    _voiceProvider?.setSpeaking(true);
  }

  void _onSpeakingStopped() {
    _robotState?.setSpeaking(false);
    _voiceProvider?.setSpeaking(false);
  }

  void _onVolumeChanged(double volume) {
    _voiceProvider?.setSpeechVolume(volume);
  }
}