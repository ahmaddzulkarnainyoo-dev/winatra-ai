import 'package:flutter/material.dart';
import 'package:onenm_local_llm/onenm_local_llm.dart';
import '../services/limit_service.dart';
import '../services/rag_service.dart';
import '../widgets/animated_pressable.dart';

class OfflineAIScreen extends StatefulWidget {
  const OfflineAIScreen({super.key});

  @override
  State<OfflineAIScreen> createState() => _OfflineAIScreenState();
}

class _OfflineAIScreenState extends State<OfflineAIScreen> {
  late OneNm _ai;
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String _statusMessage = 'Initializing...';
  bool _isInitialized = false;
  List<Map<String, dynamic>> _uploadedDocs = [];
  bool _useRAG = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAI();
    _initializeRAG();
  }

  Future<void> _initializeRAG() async {
    try {
      setState(() => _statusMessage = 'Initializing RAG...');
      final success = await RAGService.initialize();
      if (success) {
        setState(() => _statusMessage = 'RAG Ready!');
        _refreshDocuments();
      } else {
        setState(() => _statusMessage = 'RAG initialization failed');
      }
    } catch (e) {
      print('Error initializing RAG: $e');
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  Future<void> _initializeAI() async {
    try {
      setState(() => _statusMessage = 'Memeriksa model...');
      
      _ai = OneNm(
        model: OneNmModel.tinyllama,
        onProgress: (status) {
          if (mounted) {
            setState(() => _statusMessage = status);
          }
        },
      );
      
      setState(() => _statusMessage = 'Memuat model...');
      await _ai.initialize();
      
      setState(() {
        _statusMessage = 'Model siap!';
        _isInitialized = true;
      });
    } catch (e) {
      setState(() => _statusMessage = 'Error: $e');
    }
  }

  String _buildPrompt(String question, String context) {
    final instruction = 'JAWAB DALAM BAHASA INDONESIA. LANGSUNG JAWAB PERTANYAAN, JELASKAN MINIMAL 3 KALIMAT. JANGAN ULANG PERINTAH.';
    if (context.isNotEmpty) {
      return '''$instruction

Konteks:
$context

Pertanyaan: $question

Jawaban:''';
    } else {
      return '''$instruction

Pertanyaan: $question

Jawaban:''';
    }
  }

  Future<void> _uploadDocument() async {
    final filePath = await RAGService.pickDocument();
    if (filePath == null) return;

    setState(() {
      _statusMessage = 'Uploading document...';
      _isUploading = true;
      _uploadProgress = 0.12;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() => _uploadProgress = 0.42);
      final success = await RAGService.uploadDocument(filePath);
      setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 250));
      if (success) {
        setState(() => _statusMessage = 'Document uploaded successfully!');
        _refreshDocuments();
      } else {
        setState(() => _statusMessage = 'Failed to upload document');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Error uploading file: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _refreshDocuments() async {
    final docs = await RAGService.getDocuments();
    setState(() {
      _uploadedDocs = docs;
      _useRAG = docs.isNotEmpty;
    });
  }

  Future<void> _deleteDocument(String docId) async {
    final success = await RAGService.deleteDocument(docId);
    if (success) {
      setState(() => _statusMessage = 'Document deleted');
      _refreshDocuments();
    }
  }

  Future<void> _sendMessage() async {
    if (!_isInitialized) {
      setState(() => _statusMessage = 'Model belum siap, tunggu sebentar...');
      return;
    }
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    // CEK LIMIT
    if (!await LimitService.checkAndDecrementLimit()) {
      setState(() => _statusMessage = 'Maaf, kuota harian habis. Upgrade ke premium atau tunggu besok.');
      return;
    }

    setState(() {
      _messages.add({'sender': 'user', 'text': message});
      _controller.clear();
      _isLoading = true;
    });

    try {
      // Dapatkan konteks dari RAG (jika ada dokumen terupload)
      String context = '';
      if (_useRAG) {
        context = await RAGService.searchContext(message);
      }

      final prompt = _buildPrompt(message, context);
      final reply = await _ai.chat(prompt);
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': reply});
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': 'Error: $e'});
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docCount = _uploadedDocs.length;
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('🔒 Winatra Core (Offline)', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
        actions: [
          if (docCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.folder, color: Color(0xFF9B7EFF)),
                  onPressed: _showDocuments,
                  tooltip: 'Documents',
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4EFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$docCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Status & RAG Info
          AnimatedOpacity(
            opacity: _statusMessage.isNotEmpty ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              color: Colors.black26,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  if (_useRAG) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E5C3E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'RAG aktif: $docCount dokumen',
                            style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_isUploading) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF333344),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: MediaQuery.of(context).size.width * _uploadProgress - 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B4EFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Upload prompt (if no documents)
          if (docCount == 0 && !_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                border: Border.all(color: const Color(0xFF6B4EFF), width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFF9B7EFF), size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Tingkatkan Akurasi AI',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload dokumen (PDF, DOCX, TXT) untuk jawaban yang lebih akurat berdasarkan materi Anda.',
                    style: TextStyle(color: Color(0xFFCCCCDD), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _uploadDocument,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Upload Dokumen', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4EFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          // Chat messages
          Expanded(
            child: _messages.isEmpty && docCount > 0
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, color: Color(0xFF6B4EFF), size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Mulai Percakapan',
                          style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tanya pertanyaan seputar materi yang Anda upload.',
                          style: TextStyle(color: Color(0xFFCCCCDD), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
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
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            padding: const EdgeInsets.all(12.0),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isUser ? const Color(0xFF6B4EFF) : const Color(0xFF2A2A2E),
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            child: Text(
                              message['text']!,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
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
                          color: const Color(0xFF6B4EFF),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.cloud_upload, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: _isInitialized,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isInitialized ? 'Tanya AI Offline...' : 'Tunggu model siap...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedPressable(
                  onTap: (_isLoading || !_isInitialized) ? null : _sendMessage,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_isLoading || !_isInitialized) ? Colors.white12 : const Color(0xFF6B4EFF),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.folder, color: Color(0xFF9B7EFF), size: 24),
            const SizedBox(width: 8),
            Text(
              'Dokumen Saya (${_uploadedDocs.length})',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _uploadedDocs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open_outlined, color: Color(0xFF6B4EFF), size: 48),
                      const SizedBox(height: 12),
                      const Text('Belum ada dokumen', style: TextStyle(color: Color(0xFFCCCCDD))),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _uploadedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = _uploadedDocs[index];
                    final name = doc['metadata']['name'] ?? 'Unknown';
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
                          const Icon(Icons.description, color: Color(0xFF6B4EFF), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
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
            child: const Text('➕ Tambah Dokumen', style: TextStyle(color: Color(0xFF6B4EFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ai.dispose();
    RAGService.dispose();
    _controller.dispose();
    super.dispose();
  }
}