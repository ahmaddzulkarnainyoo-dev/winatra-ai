import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/brain_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../widgets/brain_mind_map.dart';
import '../../widgets/brain_document_card.dart';
import '../../widgets/download_animation.dart';

class BrainScreen extends StatefulWidget {
  const BrainScreen({super.key});

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrainProvider>().loadDocuments();
    });
  }

  Future<void> _uploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'docx', 'doc', 'md'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath == null) return;

        final fileSize = result.files.first.size;
        if (fileSize > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File terlalu besar. Maksimal 10 MB.'),
                backgroundColor: Color(0xFFFF5252),
              ),
            );
          }
          return;
        }

        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
          _uploadStatus = 'Mengupload...';
        });

        // Simulate progress
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _uploadProgress = 0.3);
          }
        });
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _uploadProgress = 0.6);
          }
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _uploadProgress = 0.9);
          }
        });

        await context.read<BrainProvider>().uploadDocument(filePath);

        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 1.0;
            _uploadStatus = 'Berhasil!';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dokumen berhasil diupload!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = 'Gagal: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String docId, String docName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Dokumen',
          style: TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Yakin ingin menghapus "$docName"?',
          style: const TextStyle(color: Color(0xFFCCCCCC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await context.read<BrainProvider>().deleteDocument(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Dokumen dihapus' : 'Gagal menghapus dokumen'),
            backgroundColor: success ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  void _useDocument(Map<String, dynamic> doc) {
    context.read<BrainProvider>().setActiveContext(doc);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${doc['name']}" dipilih sebagai konteks'),
          backgroundColor: const Color(0xFF6B4EFF),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();
    final brainProvider = context.watch<BrainProvider>();
    final docs = brainProvider.documents;
    final docCount = brainProvider.documentCount;

    return Scaffold(
      backgroundColor: appMode.bgColor,
      appBar: AppBar(
        backgroundColor: appMode.bgColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The Brain',
              style: TextStyle(
                color: appMode.headerTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Kelola pengetahuan Anda',
              style: TextStyle(
                color: appMode.textColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: appMode.accentColor),
            onPressed: () {
              // Search functionality (optional)
            },
            tooltip: 'Cari',
          ),
        ],
      ),
      body: _isUploading
          ? DownloadAnimation(
              progress: _uploadProgress,
              statusText: _uploadStatus,
              accentColor: appMode.primaryColor,
            )
          : RefreshIndicator(
              onRefresh: () => brainProvider.loadDocuments(),
              child: CustomScrollView(
                slivers: [
                  // Mind Map visualization
                  SliverToBoxAdapter(
                    child: BrainMindMap(documentCount: docCount),
                  ),

                  // Document list or empty state
                  if (docCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(Icons.folder, color: appMode.accentColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Dokumen Saya ($docCount)',
                              style: TextStyle(
                                color: appMode.headerTextColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (docCount > 0)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = docs[index];
                          return BrainDocumentCard(
                            document: doc,
                            onUse: () => _useDocument(doc),
                            onDelete: () => _deleteDocument(
                              doc['id'] as String? ?? '',
                              doc['name'] as String? ?? '',
                            ),
                          );
                        },
                        childCount: docs.length,
                      ),
                    ),

                  // Empty state
                  if (docCount == 0)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                color: appMode.accentColor.withOpacity(0.5),
                                size: 72,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Belum ada materi di The Brain',
                                style: TextStyle(
                                  color: appMode.headerTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload dokumen pertama Anda!',
                                style: TextStyle(
                                  color: appMode.textColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _uploadDocument,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text(
                                  'Upload Materi',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appMode.primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadDocument,
        backgroundColor: appMode.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}