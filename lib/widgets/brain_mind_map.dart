import 'dart:math';
import 'package:flutter/material.dart';

/// Visualisasi mind mapping untuk The Brain.
/// Menggambarkan lingkaran pusat dengan cabang-cabang ke dokumen.
class BrainMindMap extends StatelessWidget {
  final int documentCount;
  const BrainMindMap({super.key, required this.documentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4EFF).withOpacity(0.15),
            const Color(0xFF9B7EFF).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF6B4EFF).withOpacity(0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CustomPaint(
          painter: MindMapPainter(documentCount: documentCount),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_tree,
                  color: const Color(0xFF9B7EFF),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The Brain',
                      style: TextStyle(
                        color: Color(0xFF9B7EFF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$documentCount dokumen tersimpan',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MindMapPainter extends CustomPainter {
  final int documentCount;
  MindMapPainter({required this.documentCount});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final centerRadius = 28.0;
    final branchCount = documentCount.clamp(0, 5);
    final paint = Paint()
      ..color = const Color(0xFF6B4EFF).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Gambar lingkaran pusat
    canvas.drawCircle(center, centerRadius, paint..color = const Color(0xFF9B7EFF).withOpacity(0.4));
    canvas.drawCircle(center, centerRadius - 2, paint..color = const Color(0xFF9B7EFF).withOpacity(0.2)..style = PaintingStyle.fill);

    // Gambar cabang-cabang
    if (branchCount > 0) {
      for (int i = 0; i < branchCount; i++) {
        final angle = (2 * pi * i / branchCount) - pi / 2;
        final branchLength = 30.0 + (i * 5.0);
        final endX = center.dx + cos(angle) * (centerRadius + branchLength);
        final endY = center.dy + sin(angle) * (centerRadius + branchLength);
        final endPoint = Offset(endX, endY);

        // Garis cabang
        canvas.drawLine(center, endPoint, paint..color = const Color(0xFF6B4EFF).withOpacity(0.3)..style = PaintingStyle.stroke);

        // Lingkaran kecil di ujung cabang
        canvas.drawCircle(endPoint, 6, paint..color = const Color(0xFF6B4EFF).withOpacity(0.5)..style = PaintingStyle.fill);
        canvas.drawCircle(endPoint, 6, paint..color = const Color(0xFF9B7EFF).withOpacity(0.6)..style = PaintingStyle.stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MindMapPainter oldDelegate) => oldDelegate.documentCount != documentCount;
}