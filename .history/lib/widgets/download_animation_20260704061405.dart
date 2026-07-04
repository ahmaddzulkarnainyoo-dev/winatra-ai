import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'robot_character.dart';
import 'robot_speech_bubble.dart';

/// A beautiful download animation widget with robot character,
/// speech bubble, and glowing progress ring.
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

  RobotExpression _getExpression() {
    final pct = widget.progress;
    if (pct >= 1.0) return RobotExpression.excited;
    if (pct > 0.7) return RobotExpression.happy;
    if (pct > 0.3) return RobotExpression.waiting;
    return RobotExpression.waiting;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress * 100).toStringAsFixed(1);
    final isComplete = widget.progress >= 1.0;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),

            // ── Robot Character ──
            RobotCharacter(
              size: 130,
              primaryColor: const Color(0xFF6B4EFF),
              accentColor: widget.accentColor,
              expression: _getExpression(),
              isIdle: true,
            ),

            const SizedBox(height: 16),

            // ── Speech Bubble ──
            RobotSpeechBubble(
              bubbleColor: const Color(0xFF2A2A3E),
              textColor: Colors.white,
              accentColor: widget.accentColor,
              messageInterval: const Duration(seconds: 5),
            ),

            const SizedBox(height: 24),

            // ── Progress Ring ──
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow ring
                      if (!isComplete)
                        ...List.generate(3, (i) {
                          return CustomPaint(
                            size: const Size(100, 100),
                            painter: _GlowRingPainter(
                              progress: widget.progress,
                              color: widget.accentColor,
                              glowOpacity: (0.15 - (i * 0.04)) * _pulseAnim.value,
                              strokeWidth: 2.5 + (i * 1.5),
                              offset: 2.0 + (i * 2.5),
                            ),
                          );
                        }),
                      // Main progress ring
                      CustomPaint(
                        size: const Size(88, 88),
                        painter: _ProgressRingPainter(
                          progress: widget.progress,
                          color: widget.accentColor,
                          backgroundColor: widget.accentColor.withOpacity(0.15),
                          strokeWidth: 5,
                        ),
                      ),
                      // Center icon / percentage
                      if (isComplete)
                        Icon(
                          Icons.check_circle,
                          color: widget.accentColor,
                          size: 36,
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.downloading,
                              color: widget.accentColor,
                              size: 24,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                color: widget.accentColor,
                                fontSize: 14,
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

            const SizedBox(height: 20),

            // ── Status text ──
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

            // ── Hint text ──
            Text(
              isComplete
                  ? 'Model siap digunakan! 🎉'
                  : 'Jangan tutup halaman ini ya~',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
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