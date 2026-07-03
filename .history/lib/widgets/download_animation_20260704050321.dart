import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A beautiful download animation widget with glowing progress ring.
class DownloadAnimation extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String statusText;
  final Color accentColor;

  const DownloadAnimation({
    super.key,
    required this.progress,
    required this.statusText,
    this.accentColor = const Color(0xFF00CC88),
  });

  @override
  State<DownloadAnimation> createState() => _DownloadAnimationState();
}

class _DownloadAnimationState extends State<DownloadAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress * 100).toStringAsFixed(1);
    final isComplete = widget.progress >= 1.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing ring with progress
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    if (!isComplete)
                      ...List.generate(3, (i) {
                        return CustomPaint(
                          size: const Size(140, 140),
                          painter: _GlowRingPainter(
                            progress: widget.progress,
                            color: widget.accentColor,
                            glowOpacity: (0.15 - (i * 0.04)) * _pulseAnim.value,
                            strokeWidth: 3.0 + (i * 2.0),
                            offset: 2.0 + (i * 3.0),
                          ),
                        );
                      }),
                    // Main progress ring
                    CustomPaint(
                      size: const Size(120, 120),
                      painter: _ProgressRingPainter(
                        progress: widget.progress,
                        color: widget.accentColor,
                        backgroundColor: widget.accentColor.withOpacity(0.15),
                        strokeWidth: 6,
                      ),
                    ),
                    // Center icon / percentage
                    if (isComplete)
                      Icon(
                        Icons.check_circle,
                        color: widget.accentColor,
                        size: 48,
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.downloading,
                            color: widget.accentColor,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Status text
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1 * _pulseAnim.value + 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.3 * _pulseAnim.value + 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isComplete)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.accentColor,
                        ),
                      ),
                    if (!isComplete) const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        widget.statusText,
                        style: TextStyle(
                          color: widget.accentColor.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            isComplete
                ? 'Model siap digunakan!'
                : 'Jangan tutup halaman ini',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background ring
    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    // Progress arc
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

class _GlowRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double glowOpacity;
  final double strokeWidth;
  final double offset;

  _GlowRingPainter({
    required this.progress,
    required this.color,
    required this.glowOpacity,
    required this.strokeWidth,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2 - offset;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withOpacity(glowOpacity * 0.3);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) =>
      old.progress != progress || old.glowOpacity != glowOpacity;
}