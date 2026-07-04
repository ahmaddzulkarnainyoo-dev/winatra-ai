import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class RAGService {
  static final RAGService _instance = RAGService._internal();
  static List<Map<String, dynamic>> _documents = [];
  static bool _isInitialized = false;

  // ── Constants ──
  static const int CHUNK_SIZE = 512;
  static const int CHUNK_OVERLAP = 50;
  static const int MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB
  static const int MAX_PDF_PAGES = 50;

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

  /// Upload dokumen dari file (simpan konten ke memory dengan chunking)
  static Future<bool> uploadDocument(String filePath) async {
    if (!_isInitialized) {
      print('RAGService: Service not initialized');
      return false;
    }

    try {
      final fileName = filePath.split(Platform.pathSeparator).last;
      print('RAGService: Reading document: $fileName');

      final file = File(filePath);
      if (!await file.exists()) {
        print('RAGService: File does not exist: $filePath');
        return false;
      }

      // ── Check file size limit ──
      final fileSize = await file.length();
      if (fileSize > MAX_FILE_SIZE_BYTES) {
        throw Exception('File terlalu besar (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Maksimal 10 MB.');
      }

      // ── Check page limit for PDF ──
      final extension = filePath.split('.').last.toLowerCase();
      if (extension == 'pdf') {
        final bytes = await file.readAsBytes();
        try {
          final pdfDoc = PdfDocument(inputBytes: bytes);
          final pageCount = pdfDoc.pages.count;
          pdfDoc.dispose();
          if (pageCount > MAX_PDF_PAGES) {
            throw Exception('PDF terlalu banyak halaman ($pageCount halaman). Maksimal $MAX_PDF_PAGES halaman.');
          }
        } catch (e) {
          if (e is Exception) rethrow;
          // If PDF parsing fails here, let extractTextFromFile handle it
        }
      }

      // Baca isi file sesuai tipe
      final content = await extractTextFromFile(filePath);
      if (content.isEmpty) {
        print('RAGService: Extracted content is empty for $fileName');
        return false;
      }

      // ── Chunking: bagi konten menjadi chunks 512 karakter ──
      final chunks = _chunkText(content);

      // Simpan ke memory
      _documents.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': fileName,
        'path': filePath,
        'content': content,
        'chunks': chunks,
        'uploadedAt': DateTime.now().toIso8601String(),
      });

      print('RAGService: Document uploaded successfully (${content.length} chars, ${chunks.length} chunks)');
      return true;
    } catch (e) {
      print('RAGService: Error uploading document: $e');
      rethrow;
    }
  }

  /// Bagi teks menjadi chunks dengan overlap
  static List<Map<String, dynamic>> _chunkText(String text) {
    final chunks = <Map<String, dynamic>>[];
    if (text.isEmpty) return chunks;

    int start = 0;
    int chunkIndex = 0;

    while (start < text.length) {
      int end = start + CHUNK_SIZE;
      if (end > text.length) end = text.length;

      String chunk = text.substring(start, end);

      // Jika bukan chunk terakhir, coba potong di akhir kalimat
      if (end < text.length) {
        final lastPeriod = chunk.lastIndexOf('. ');
        final lastNewline = chunk.lastIndexOf('\n');
        final breakPoint = lastPeriod > lastNewline ? lastPeriod + 1 : lastNewline;
        if (breakPoint > start + CHUNK_SIZE ~/ 2) {
          chunk = text.substring(start, breakPoint);
          end = breakPoint;
        }
      }

      chunks.add({
        'index': chunkIndex,
        'text': chunk.trim(),
        'startPos': start,
      });

      // Move start with overlap
      start = end - CHUNK_OVERLAP;
      if (start < 0) start = 0;
      chunkIndex++;
    }

    return chunks;
  }

  static Future<String> extractTextFromFile(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    if (extension == 'txt' || extension == 'md') {
      return await file.readAsString();
    }

    if (extension == 'docx') {
      return await _extractTextFromDocx(file);
    }

    if (extension == 'pdf') {
      return await _extractTextFromPdf(file);
    }

    if (extension == 'doc') {
      return await file.readAsString();
    }

    throw Exception('Tipe file tidak didukung: $extension');
  }

  static Future<String> _extractTextFromDocx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentEntry = archive.files.firstWhere(
      (entry) => entry.name.toLowerCase() == 'word/document.xml',
      orElse: () => throw Exception('File DOCX tidak valid: document.xml tidak ditemukan'),
    );
    final xmlContent = utf8.decode(documentEntry.content as List<int>);
    final textMatches = RegExp(r'<w:t[^>]*>(.*?)<\/w:t>', dotAll: true)
        .allMatches(xmlContent)
        .map((match) => match.group(1) ?? '')
        .toList();
    return textMatches.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extract text from PDF using syncfusion_flutter_pdf
  static Future<String> _extractTextFromPdf(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final pdfDoc = PdfDocument(inputBytes: bytes);
      final buffer = StringBuffer();

      for (int i = 0; i < pdfDoc.pages.count; i++) {
        final page = pdfDoc.pages[i];
        final text = PdfTextExtractor(pdfDoc).extractText(startPageIndex: i, endPageIndex: i);
        buffer.writeln(text);
        buffer.writeln();
      }

      pdfDoc.dispose();
      return buffer.toString().trim();
    } catch (e) {
      print('RAGService: PDF extraction error: $e');
      // Fallback: regex-based extraction
      final bytes = await file.readAsBytes();
      final raw = latin1.decode(bytes, allowInvalid: true);
      if (!raw.contains('%PDF')) {
        throw Exception('File PDF tidak valid');
      }

      final matches = RegExp(r'\(([^)]*)\)').allMatches(raw);
      final buffer = StringBuffer();
      for (final match in matches) {
        buffer.write(match.group(1));
        buffer.write(' ');
      }

      return buffer.toString()
          .replaceAll(RegExp(r'\\[nrtbf]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  /// Cari konteks relevan dari dokumen (search di level chunk)
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

      final queryLower = query.toLowerCase();
      final results = <Map<String, dynamic>>[];

      for (final doc in _documents) {
        final chunks = doc['chunks'] as List<Map<String, dynamic>>? ?? [];
        final name = doc['name'] as String? ?? '';

        for (final chunk in chunks) {
          final chunkText = chunk['text'] as String? ?? '';
          final chunkLower = chunkText.toLowerCase();
          int score = 0;
          final keywords = queryLower.split(RegExp(r'\s+')).where((k) => k.length > 2);

          for (final keyword in keywords) {
            score += chunkLower.split(keyword).length - 1;
          }

          if (score > 0) {
            results.add({
              'score': score,
              'content': chunkText,
              'name': name,
            });
          }
        }
      }

      if (results.isEmpty) {
        print('RAGService: No relevant chunks found');
        return '';
      }

      results.sort((a, b) => b['score'].compareTo(a['score']));
      final topResults = results.take(topK);
      final buffer = StringBuffer();
      const maxContextLength = 1500;

      for (final result in topResults) {
        final content = result['content'] as String;
        final name = result['name'] as String;
        final chunk = '[$name] $content';
        if (buffer.length + chunk.length > maxContextLength) {
          break;
        }
        buffer.writeln(chunk);
        buffer.writeln();
        if (buffer.length >= maxContextLength) break;
      }

      if (buffer.isNotEmpty) {
        final context = buffer.toString().trim();
        print('RAGService: Found relevant context (${context.length} chars)');
        return context;
      }

      // Fallback: ambil chunk pertama dari dokumen dengan skor tertinggi
      final fallbackContent = results.first['content'] as String;
      final fallback = fallbackContent.length <= 500
          ? fallbackContent
          : fallbackContent.substring(0, 500);
      print('RAGService: Using fallback chunk (${fallback.length} chars)');
      return fallback;
    } catch (e) {
      print('RAGService: Error searching context: $e');
      return '';
    }
  }

  /// Dapatkan list dokumen yang sudah diupload
  static Future<List<Map<String, dynamic>>> getDocuments() async {
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
      // Request permission with better handling for Android 13+
      bool permissionGranted = false;

      try {
        final status = await Permission.storage.request();
        permissionGranted = status.isGranted;
      } catch (e) {
        // On Android 13+, storage permission may not be needed
        // file_picker can work without it
        print('RAGService: Permission request skipped (may not be needed): $e');
        permissionGranted = true;
      }

      if (!permissionGranted) {
        // Try to open settings
        try {
          await openAppSettings();
        } catch (_) {}
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