import 'package:flutter/material.dart';
import '../providers/app_mode_provider.dart';

/// Card widget for displaying a document in The Brain.
class BrainDocumentCard extends StatelessWidget {
  final Map<String, dynamic> document;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  const BrainDocumentCard({
    super.key,
    required this.document,
    required this.onUse,
    required this.onDelete,
  });

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'txt':
      case 'md':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFFF5252);
      case 'docx':
      case 'doc':
        return const Color(0xFF448AFF);
      case 'txt':
      case 'md':
        return const Color(0xFF66BB6A);
      default:
        return const Color(0xFF9B7EFF);
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Unknown';
    final bytes = double.tryParse(size.toString()) ?? 0;
    if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = AppModeProvider();
    final fileName = document['name'] as String? ?? 'Unknown';
    final status = document['status'] as String? ?? 'Siap';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getFileColor(fileName).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getFileIcon(fileName),
                color: _getFileColor(fileName),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatFileSize(document['size']),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      if (document['uploadedAt'] != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(document['uploadedAt'] as String?),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Status badge
                  _buildStatusBadge(status),
                ],
              ),
            ),

            // Action buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Use button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B4EFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: onUse,
                    icon: const Icon(Icons.play_arrow, color: Color(0xFF9B7EFF), size: 20),
                    tooltip: 'Gunakan',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                const SizedBox(height: 4),
                // Delete button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252), size: 20),
                    tooltip: 'Hapus',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'Sedang diproses':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFA726).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: const Color(0xFFFFA726),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Sedang diproses',
                style: TextStyle(color: Color(0xFFFFA726), fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      case 'Gagal':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5252).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 10),
              SizedBox(width: 4),
              Text(
                'Gagal',
                style: TextStyle(color: Color(0xFFFF5252), fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      default: // Siap
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 10),
              SizedBox(width: 4),
              Text(
                'Siap',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
    }
  }
}