import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_mode_provider.dart';
import '../providers/brain_provider.dart';
import '../services/ai_service.dart';
import '../services/limit_service.dart';
import '../services/rag_service.dart';
import '../services/chat_history_service.dart';
import '../widgets/animated_pressable.dart';
import '../widgets/download_animation.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final AIService _aiService = AIService();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isInitializingLocal = false;
  String _statusMessage = '';
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _checkLocalModel();
  }

  Future<void> _loadChatHistory() async {
    final savedMessages = ChatHistoryService.loadMessages();
    if (savedMessages.isNotEmpty && mounted) {
      setState(() {
        _messages.addAll(savedMessages);
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveChatHistory() async {
    await ChatHistoryService.saveMessages(_messages);
  }

  Future<void> _checkLocalModel() async {
    if (_aiService.isLocalReady) return;
  }

  Future<void> _initLocalAI() async {
    if (_aiService.isLocalReady) return;

    setState(() {
      _isInitializingLocal = true;
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Memulai...';
    });

    try {
      await _aiService.initLocal(
        onProgress: (status) {
          if (!mounted) return;
          setState(() {
            _statusMessage = status;
            final pctMatch = RegExp(r'(\d+\.?\d*)%').firstMatch(status);
            if (pctMatch != null) {
              _downloadProgress = double.parse(pctMatch.group(1)!) / 100.0;
            } else if (status.contains('Download complete')) {
              _downloadProgress = 1.0;
            } else if (status.contains('Loading model')) {
              _downloadProgress = 0.95;
            } else if (status.contains('Ready')) {
              _downloadProgress = 1.0;
            }
          });
        },
      );
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInitializingLocal = false;
          _statusMessage = 'Model siap! Silakan chat.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInitializingLocal = false;
          _statusMessage = 'Gagal memuat model: $e';
        });
      }
    }
  }

  Future<void> _clearChat() async {
    setState(() {
      _messages.clear();
    });
    await ChatHistoryService.clearHistory();
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final appMode = context.read<AppModeProvider>();

    // If offline and local AI not ready, init first
    if (appMode.isOffline && !_aiService.isLocalReady) {
      await _initLocalAI();
      if (!_aiService.isLocalReady) {
        setState(() => _statusMessage = 'Model offline belum siap. Coba lagi.');
        return;
      }
    }

    // Check limit
    if (!await LimitService.checkAndDecrementLimit()) {
      setState(() => _statusMessage = 'Kuota harian habis. Upgrade ke premium atau tunggu besok.');
      return;
    }

    setState(() {
      _messages.add({'sender': 'user', 'text': message});
      _controller.clear();
      _isLoading = true;
      _statusMessage = appMode.isOffline ? 'Memproses offline...' : 'Menghubungi server...';
    });
    _saveChatHistory();

    try {
      // Get RAG context from The Brain (all documents)
      String context = '';
      try {
        context = await RAGService.searchContext(message);
      } catch (_) {}

      final systemPrompt = context.isNotEmpty
          ? '''Kamu adalah Winatra AI, asisten belajar yang membantu.
JAWABLAH DALAM BAHASA INDONESIA.
Gunakan konteks berikut untuk menjawab pertanyaan:

$context'''
          : null;

      final reply = await _aiService.chat(
        message: message,
        isOffline: appMode.isOffline,
        systemPrompt: systemPrompt,
      );

      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': reply});
          _isLoading = false;
          _statusMessage = '';
        });
        _saveChatHistory();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': 'Error: $e'});
          _isLoading = false;
          _statusMessage = '';
        });
        _saveChatHistory();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();
    final brainProvider = context.watch<BrainProvider>();
    final docCount = brainProvider.documentCount;
    final activeDoc = brainProvider.activeContextDoc;

    return Scaffold(
      backgroundColor: appMode.bgColor,
      appBar: AppBar(
        backgroundColor: appMode.bgColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              appMode.isOffline ? Icons.cloud_off : Icons.cloud,
              color: appMode.accentColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Ngobrol Bareng Winatra',
              style: TextStyle(
                color: appMode.headerTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          // Mode indicator
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: appMode.isOffline
                  ? const Color(0xFF00CC88).withOpacity(0.2)
                  : const Color(0xFF6B4EFF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: appMode.isOffline
                    ? const Color(0xFF00CC88).withOpacity(0.5)
                    : const Color(0xFF6B4EFF).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  appMode.isOffline ? Icons.lock : Icons.public,
                  size: 12,
                  color: appMode.isOffline
                      ? const Color(0xFF00CC88)
                      : const Color(0xFF6B4EFF),
                ),
                const SizedBox(width: 4),
                Text(
                  appMode.isOffline ? 'Offline' : 'Online',
                  style: TextStyle(
                    color: appMode.isOffline
                        ? const Color(0xFF00CC88)
                        : const Color(0xFF6B4EFF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // New Chat button
          IconButton(
            icon: Icon(Icons.add_comment, color: appMode.accentColor, size: 20),
            onPressed: _clearChat,
            tooltip: 'Chat Baru',
          ),
        ],
      ),
      body: Column(
        children: [
          // Context indicator bar
          if (docCount > 0)
            GestureDetector(
              onTap: () {
                // Show context selection dialog
                _showContextSelector();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF6B4EFF).withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.account_tree, color: appMode.accentColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeDoc != null
                            ? 'Konteks: ${activeDoc['name']}'
                            : '$docCount dokumen tersedia di The Brain',
                        style: TextStyle(
                          color: appMode.accentColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: appMode.accentColor, size: 18),
                  ],
                ),
              ),
            ),

          // Status bar
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: appMode.surfaceColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading || _isDownloading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: appMode.accentColor,
                      ),
                    ),
                  if (_isLoading || _isDownloading) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: appMode.textColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Download animation (when downloading model)
          if (_isDownloading)
            Expanded(
              child: DownloadAnimation(
                progress: _downloadProgress,
                statusText: _statusMessage,
                accentColor: appMode.primaryColor,
              ),
            ),

          // Chat messages
          if (!_isDownloading)
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: appMode.accentColor, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Mulai Percakapan',
                            style: TextStyle(
                              color: appMode.headerTextColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            appMode.isOffline
                                ? 'Mode offline aktif. AI berjalan di perangkat Anda.'
                                : 'Tanya apa saja, Winatra siap membantu!',
                            style: TextStyle(
                              color: appMode.textColor,
                              fontSize: 12,
                            ),
                          ),
                          if (docCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Materi dari The Brain akan digunakan sebagai konteks.',
                                style: TextStyle(
                                  color: appMode.accentColor.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (appMode.isOffline && !_aiService.isLocalReady)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: ElevatedButton.icon(
                                onPressed: _initLocalAI,
                                icon: const Icon(Icons.download, color: Colors.white),
                                label: const Text('Download Model AI',
                                    style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appMode.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isUser = message['sender'] == 'user';
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 12),
                                child: child,
                              ),
                            );
                          },
                          child: Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              padding: const EdgeInsets.all(12.0),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? appMode.primaryColor
                                    : appMode.surfaceColor,
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Text(
                                message['text']!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

          // Input bar
          if (!_isDownloading)
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: appMode.bgColor,
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tanya Winatra...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1E1E24),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedPressable(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isLoading
                            ? Colors.white12
                            : appMode.primaryColor,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: appMode.accentColor,
                              ),
                            )
                          : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showContextSelector() {
    final brainProvider = context.read<BrainProvider>();
    final docs = brainProvider.documents;
    final appMode = context.read<AppModeProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_tree, color: appMode.accentColor, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Pilih Materi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih dokumen dari The Brain sebagai konteks jawaban AI',
                    style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Belum ada dokumen di The Brain',
                          style: TextStyle(color: Color(0xFFCCCCCC)),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final name = doc['name'] as String? ?? 'Unknown';
                          final isActive = brainProvider.activeContextDoc?['id'] == doc['id'];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF6B4EFF).withOpacity(0.15)
                                  : const Color(0xFF2A2A2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF6B4EFF).withOpacity(0.5)
                                    : Colors.white10,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.description,
                                color: isActive
                                    ? const Color(0xFF9B7EFF)
                                    : Colors.white54,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF9B7EFF) : Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: isActive
                                  ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20)
                                  : null,
                              onTap: () {
                                brainProvider.setActiveContext(isActive ? null : doc);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        brainProvider.setActiveContext(null);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Nonaktifkan Konteks',
                        style: TextStyle(color: Color(0xFFFF5252)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}