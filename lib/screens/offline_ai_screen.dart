import 'package:flutter/material.dart';
import 'package:onenm_local_llm/onenm_local_llm.dart';
import '../services/limit_service.dart';
import '../services/rag_service.dart';

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
    if (context.isNotEmpty) {
      return '''
Anda adalah asisten AI yang ramah, cerdas, dan suka membantu. Jawab pertanyaan berikut dengan BAHASA INDONESIA yang baik dan benar.

Gunakan informasi dari TEKS yang disediakan sebagai sumber utama jawaban Anda. Jika teks tidak mengandung jawaban, katakan "Berdasarkan materi yang diupload, informasi tentang pertanyaan ini tidak tersedia." Jangan mengarang jawaban.

**Aturan penting:**
- JANGAN menjawab dengan satu kata. Berikan penjelasan minimal 3 kalimat.
- JANGAN menggunakan bahasa Inggris kecuali untuk istilah teknis yang tidak ada padanannya (itupun beri penjelasan).
- Jawab dengan jelas, terstruktur, dan mudah dipahami oleh pelajar.

TEKS YANG DIUPLOAD:
$context

PERTANYAAN: $question

JAWABAN (dalam Bahasa Indonesia, minimal 3 kalimat):''';
    } else {
      return '''
Anda adalah asisten AI yang ramah, cerdas, dan suka membantu. Jawab pertanyaan berikut dengan BAHASA INDONESIA yang baik dan benar.

**Aturan penting:**
- JANGAN menjawab dengan satu kata. Berikan penjelasan minimal 3 kalimat.
- JANGAN menggunakan bahasa Inggris kecuali untuk istilah teknis.
- Jika tidak tahu, katakan "Maaf, saya belum bisa menjawab pertanyaan itu dengan yakin. Silakan tanyakan hal lain atau upload materi terkait."

PERTANYAAN: $question

JAWABAN (dalam Bahasa Indonesia, minimal 3 kalimat):''';
    }
  }

  Future<void> _uploadDocument() async {
    final filePath = await RAGService.pickDocument();
    if (filePath != null) {
      setState(() => _statusMessage = 'Uploading document...');
      final success = await RAGService.uploadDocument(filePath);
      if (success) {
        setState(() => _statusMessage = 'Document uploaded successfully!');
        _refreshDocuments();
      } else {
        setState(() => _statusMessage = 'Failed to upload document');
      }
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Winatra Core', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file, color: Color(0xFF9B7EFF)),
            onPressed: _uploadDocument,
            tooltip: 'Upload Document',
          ),
          if (_uploadedDocs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.folder, color: Color(0xFF9B7EFF)),
              onPressed: _showDocuments,
              tooltip: 'Manage Documents',
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black26,
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                if (_useRAG)
                  Text(
                    '✓ Using ${_uploadedDocs.length} document(s) for RAG',
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                final isUser = message['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF6B4EFF) : const Color(0xFF2A2A2E),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      message['text']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tanya AI Offline...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1E24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF6B4EFF)),
                  onPressed: _isLoading ? null : _sendMessage,
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
        title: const Text('Uploaded Documents', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: _uploadedDocs.length,
            itemBuilder: (context, index) {
              final doc = _uploadedDocs[index];
              final name = doc['metadata']['name'] ?? 'Unknown';
              final docId = doc['id'] ?? '';
              return ListTile(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _deleteDocument(docId);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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