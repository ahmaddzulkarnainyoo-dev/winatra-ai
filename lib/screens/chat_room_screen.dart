import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_mode_provider.dart';
import '../services/ai_service.dart';
import '../services/limit_service.dart';
import '../services/rag_service.dart';
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

  // RAG
  List<Map<String, dynamic>> _uploadedDocs = [];
  bool _useRAG = false;

  @override
  void initState() {
    super.initState();
    _initializeRAG();
    _checkLocalModel();
  }

  Future<void> _checkLocalModel() async {
    // If already initialized, skip
    if (_aiService.isLocalReady) return;
  }

  Future<void> _initializeRAG() async {
    try {
      final success = await RAGService.initialize();
      if (success) {
        _refreshDocuments();
      }
    } catch (e) {
      print('RAG init error: $e');
    }
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
            // Parse progress from status like "Downloading... (42.3%)"
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

  Future<void> _refreshDocuments() async {
    final docs = await RAGService.getDocuments();
    if (mounted) {
      setState(() {
        _uploadedDocs = docs;
        _useRAG = docs.isNotEmpty;
      });
    }
  }

  Future<void> _uploadDocument() async {
    final filePath = await RAGService.pickDocument();
    if (filePath == null) return;

    setState(() {
      _statusMessage = 'Mengupload dokumen...';
    });

    try {
      final success = await RAGService.uploadDocument(filePath);
      if (success) {
        setState(() => _statusMessage = 'Dokumen berhasil diupload!');
        _refreshDocuments();
      } else {
        setState(() => _statusMessage = 'Gagal mengupload dokumen.');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  Future<void> _deleteDocument(String docId) async {
    final success = await RAGService.deleteDocument(docId);
    if (success) {
      setState(() => _statusMessage = 'Dokumen dihapus');
      _refreshDocuments();
    }
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

    try {
      // Get RAG context if available
      String context = '';
      if (_useRAG) {
        context = await RAGService.searchContext(message);
      }

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
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': 'Error: $e'});
          _isLoading = false;
          _statusMessage = '';
        });
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
    final docCount = _uploadedDocs.length;

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
            margin: const EdgeInsets.only(right: 8),
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
          // Document count badge
          if (docCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.folder, color: appMode.accentColor),
                  onPressed: _showDocuments,
                  tooltip: 'Dokumen',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: appMode.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$docCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
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

          // Upload prompt (if no documents and not downloading)
          if (docCount == 0 && !_isLoading && !_isDownloading && _messages.isEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appMode.surfaceColor,
                border: Border.all(color: appMode.cardBorderColor, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      color: appMode.accentColor, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Upload Materi Belajar',
                    style: TextStyle(
                      color: appMode.headerTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload PDF, DOCX, atau TXT untuk jawaban yang lebih akurat berdasarkan materi Anda.',
                    style: TextStyle(color: appMode.textColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _uploadDocument,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Upload Dokumen',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appMode.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
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
                  if (docCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedPressable(
                        onTap: _uploadDocument,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: appMode.primaryColor,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.cloud_upload,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
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

  void _showDocuments() {
    final appMode = context.read<AppModeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.folder, color: appMode.accentColor, size: 24),
            const SizedBox(width: 8),
            Text(
              'Dokumen Saya (${_uploadedDocs.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _uploadedDocs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open_outlined,
                          color: Color(0xFF6B4EFF), size: 48),
                      const SizedBox(height: 12),
                      const Text('Belum ada dokumen',
                          style: TextStyle(color: Color(0xFFCCCCDD))),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _uploadedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = _uploadedDocs[index];
                    final name = doc['name'] ?? 'Unknown';
                    final docId = doc['id'] ?? '';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description,
                              color: Color(0xFF6B4EFF), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            onPressed: () {
                              _deleteDocument(docId);
                              Navigator.pop(context);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: _uploadDocument,
            child: const Text('➕ Tambah Dokumen',
                style: TextStyle(color: Color(0xFF6B4EFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}