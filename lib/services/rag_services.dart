// Deprecated: Use rag_service.dart instead
// This file is kept for reference only and should not be imported

/*
// lib/services/rag_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:docx/docx.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';

class RAGService {
  static final RAGService _instance = RAGService._internal();
  factory RAGService() => _instance;
  RAGService._internal();

  late MobileRagEngine _engine;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final appDir = await getApplicationDocumentsDirectory();
    final ragDir = Directory('${appDir.path}/rag_data');
    if (!await ragDir.exists()) await ragDir.create();
    
    _engine = MobileRagEngine(
      storagePath: ragDir.path,
      // Model embedding akan diunduh otomatis pertama kali
    );
    await _engine.initialize();
    _isInitialized = true;
  }

  // Ekstrak teks dari file (PDF/DOCX/TXT)
  Future<String> extractTextFromFile(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    
    if (extension == 'pdf') {
      final pdfDocument = PdfDocument(inputBytes: await File(filePath).readAsBytes());
      final text = StringBuffer();
      for (int i = 0; i < pdfDocument.pages.count; i++) {
        final page = pdfDocument.pages[i];
        text.write(page.extractText());
      }
      pdfDocument.dispose();
      return text.toString();
    } 
    else if (extension == 'docx') {
      final docx = await Docx.fromPath(filePath);
      final text = docx.text;
      docx.dispose();
      return text;
    } 
    else if (extension == 'txt') {
      return await File(filePath).readAsString();
    } 
    else {
      throw Exception('Format file tidak didukung: $extension');
    }
  }

  // Upload dokumen ke RAG engine (otomatis chunk + embedding + simpan)
  Future<void> addDocument(String filePath, {String? title}) async {
    if (!_isInitialized) await initialize();
    
    final text = await extractTextFromFile(filePath);
    if (text.trim().isEmpty) throw Exception('File kosong atau tidak bisa dibaca');
    
    final docTitle = title ?? filePath.split('/').last;
    await _engine.addDocument(
      text: text,
      metadata: {'title': docTitle, 'path': filePath},
    );
  }

  // Cari chunk relevan berdasarkan pertanyaan
  Future<List<Map<String, dynamic>>> search(String query, {int topK = 5}) async {
    if (!_isInitialized) await initialize();
    final results = await _engine.search(query, topK: topK);
    return results.map((r) => {
      'text': r.text,
      'score': r.score,
      'metadata': r.metadata,
    }).toList();
  }

  // Dapatkan konteks dari hasil pencarian untuk diprompt ke AI
  Future<String> getContextForQuery(String query) async {
    final results = await search(query);
    if (results.isEmpty) return '';
    
    final context = StringBuffer();
    for (int i = 0; i < results.length; i++) {
      context.writeln('[${i+1}] ${results[i]['text']}\n');
    }
    return context.toString();
  }

  // Hapus semua data RAG
  Future<void> clearAll() async {
    if (!_isInitialized) await initialize();
    await _engine.clear();
  }
  
  void dispose() {
    _engine.dispose();
  }
}
*/