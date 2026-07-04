import 'package:flutter/material.dart';
import '../services/rag_service.dart';

/// Provider for managing The Brain state - documents, context selection,
/// and providing context for keyboard/notification services.
class BrainProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _activeContextDoc;
  bool _isLoading = false;
  String _statusMessage = '';

  List<Map<String, dynamic>> get documents => _documents;
  Map<String, dynamic>? get activeContextDoc => _activeContextDoc;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  int get documentCount => _documents.length;

  /// Load all documents from RAGService
  Future<void> loadDocuments() async {
    _isLoading = true;
    _statusMessage = 'Memuat dokumen...';
    notifyListeners();

    try {
      await RAGService.initialize();
      _documents = await RAGService.getDocuments();
      _statusMessage = '';
    } catch (e) {
      _statusMessage = 'Gagal memuat dokumen: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Set active context document for chat
  void setActiveContext(Map<String, dynamic>? doc) {
    _activeContextDoc = doc;
    notifyListeners();
  }

  /// Upload a document and refresh the list
  Future<bool> uploadDocument(String filePath) async {
    _isLoading = true;
    _statusMessage = 'Mengupload dokumen...';
    notifyListeners();

    try {
      final success = await RAGService.uploadDocument(filePath);
      if (success) {
        _documents = await RAGService.getDocuments();
        _statusMessage = 'Dokumen berhasil diupload!';
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _statusMessage = 'Gagal mengupload dokumen.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _statusMessage = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a document and refresh the list
  Future<bool> deleteDocument(String docId) async {
    final success = await RAGService.deleteDocument(docId);
    if (success) {
      if (_activeContextDoc?['id'] == docId) {
        _activeContextDoc = null;
      }
      _documents = await RAGService.getDocuments();
      notifyListeners();
    }
    return success;
  }

  /// Search all documents for context (used by keyboard/notification)
  Future<String> searchAllDocuments(String query) async {
    return await RAGService.searchContext(query);
  }

  /// Get all documents as a list (for keyboard/notification services)
  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    return await RAGService.getDocuments();
  }

  /// Clear all documents
  Future<bool> clearAll() async {
    final success = await RAGService.clearAll();
    if (success) {
      _activeContextDoc = null;
      _documents = [];
      notifyListeners();
    }
    return success;
  }
}