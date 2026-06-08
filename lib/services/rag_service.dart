import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RAGService {
  static final RAGService _instance = RAGService._internal();
  static List<Map<String, String>> _documents = [];
  static bool _isInitialized = false;
  
  factory RAGService() {
    return _instance;
  }

  RAGService._internal();

  /// Initialize RAG service
  static Future<bool> initialize() async {
    if (_isInitialized) {
      print('RAGService: Already initialized');
      return true;
    }

    try {
      print('RAGService: Initializing...');
      _isInitialized = true;
      print('RAGService: Initialized successfully');
      return true;
    } catch (e) {
      print('RAGService: Error initializing: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Upload dokumen dari file (simpan konten ke memory)
  static Future<bool> uploadDocument(String filePath) async {
    if (!_isInitialized) {
      print('RAGService: Service not initialized');
      return false;
    }

    try {
      final fileName = filePath.split('/').last;
      print('RAGService: Reading document: $fileName');
      
      final file = File(filePath);
      if (!await file.exists()) {
        print('RAGService: File does not exist: $filePath');
        return false;
      }

      // Baca isi file
      final content = await file.readAsString();
      
      // Simpan ke memory
      _documents.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': fileName,
        'path': filePath,
        'content': content,
        'uploadedAt': DateTime.now().toIso8601String(),
      });
      
      print('RAGService: Document uploaded successfully (${content.length} chars)');
      return true;
    } catch (e) {
      print('RAGService: Error uploading document: $e');
      return false;
    }
  }

  /// Cari konteks relevan dari dokumen (simple string search)
  static Future<String> searchContext(String query, {int topK = 3}) async {
    if (!_isInitialized) {
      print('RAGService: Service not initialized');
      return '';
    }

    try {
      print('RAGService: Searching context for query: "$query"');
      
      if (_documents.isEmpty) {
        print('RAGService: No documents uploaded');
        return '';
      }

      // Simple relevance scoring: count keyword matches
      final results = <Map<String, dynamic>>[];
      
      for (final doc in _documents) {
        final content = doc['content'] ?? '';
        final queryLower = query.toLowerCase();
        final contentLower = content.toLowerCase();
        
        // Hitung score berdasarkan keyword match
        int score = 0;
        final keywords = queryLower.split(' ');
        for (final keyword in keywords) {
          if (keyword.length > 2) {
            // Count occurrences
            score += contentLower.split(keyword).length - 1;
          }
        }

        if (score > 0) {
          results.add({
            'score': score,
            'content': content,
            'name': doc['name'],
          });
        }
      }

      if (results.isEmpty) {
        print('RAGService: No relevant documents found');
        return '';
      }

      // Sort by score
      results.sort((a, b) => b['score'].compareTo(a['score']));

      // Ambil top K chunks (split by paragraf)
      final topResults = results.take(topK);
      
      // Gabungkan menjadi satu konteks
      final contextParts = <String>[];
      for (final result in topResults) {
        final content = result['content'] as String;
        final name = result['name'] as String;
        
        // Split by paragraph, ambil yang relevant
        final paragraphs = content.split('\n\n');
        for (final para in paragraphs) {
          if (para.toLowerCase().contains(query.toLowerCase())) {
            contextParts.add('[$name] $para');
            if (contextParts.length >= topK) break;
          }
        }
        if (contextParts.length >= topK) break;
      }

      final context = contextParts.isNotEmpty 
        ? contextParts.join('\n\n') 
        : (results.first['content'] as String).substring(0, 500);

      print('RAGService: Found ${contextParts.length} relevant chunks');
      return context;
    } catch (e) {
      print('RAGService: Error searching context: $e');
      return '';
    }
  }

  /// Dapatkan list dokumen yang sudah diupload
  static Future<List<Map<String, String>>> getDocuments() async {
    if (!_isInitialized) {
      print('RAGService: Service not initialized');
      return [];
    }

    try {
      print('RAGService: Found ${_documents.length} documents');
      return _documents.map((doc) => {
        'id': doc['id'] ?? '',
        'name': doc['name'] ?? '',
        'uploadedAt': doc['uploadedAt'] ?? '',
      }).toList();
    } catch (e) {
      print('RAGService: Error fetching documents: $e');
      return [];
    }
  }

  /// Hapus dokumen
  static Future<bool> deleteDocument(String documentId) async {
    if (!_isInitialized) {
      print('RAGService: Service not initialized');
      return false;
    }

    try {
      print('RAGService: Deleting document: $documentId');
      _documents.removeWhere((doc) => doc['id'] == documentId);
      print('RAGService: Document deleted successfully');
      return true;
    } catch (e) {
      print('RAGService: Error deleting document: $e');
      return false;
    }
  }

  /// Pilih file dokumen (PDF, TXT, DOCX, dll)
  static Future<String?> pickDocument() async {
    try {
      // Request permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        print('RAGService: Storage permission denied');
        return null;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx', 'doc', 'md'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        print('RAGService: File picked: $filePath');
        return filePath;
      }

      print('RAGService: No file selected');
      return null;
    } catch (e) {
      print('RAGService: Error picking file: $e');
      return null;
    }
  }

  /// Clear semua dokumen
  static Future<bool> clearAll() async {
    if (!_isInitialized) {
      print('RAGService: Service not initialized');
      return false;
    }

    try {
      print('RAGService: Clearing all documents...');
      _documents.clear();
      print('RAGService: All documents cleared');
      return true;
    } catch (e) {
      print('RAGService: Error clearing documents: $e');
      return false;
    }
  }

  /// Dispose service
  static void dispose() {
    try {
      if (_isInitialized) {
        print('RAGService: Disposing...');
        _documents.clear();
        _isInitialized = false;
      }
    } catch (e) {
      print('RAGService: Error disposing: $e');
    }
  }
}

