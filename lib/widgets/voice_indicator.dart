import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated voice indicator widget showing sound wave bars.
/// Visual feedback for STT (listening) and TTS (speaking) states.
class VoiceIndicator extends StatefulWidget {
  final bool isActive;
  final double volume; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;
  final int barCount;

  const VoiceIndicator({
    super.key,
    this.isActive = false,
    this.volume = 0.0,
    this.activeColor = const Color(0xFF6B4EFF),
    this.inactiveColor = const Color(0xFF333355),
    this.barCount = 5,
  });

  @override
  State<VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends State<VoiceIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isActive) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _animController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _animController.stop();
      _animController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.barCount, (index) {
            final normalizedIndex = index / (widget.barCount - 1);
            // Each bar has a different phase
            final phase = (normalizedIndex * 2.0 + _animController.value) % 1.0;
            final heightFactor = widget.isActive
                ? 0.3 + 0.7 * math.sin(phase * math.pi) * (0.5 + widget.volume * 0.5)
                : 0.2;

            return Container(
              width: 4,
              height: 24 * heightFactor,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? widget.activeColor.withOpacity(0.6 + 0.4 * heightFactor)
                    : widget.inactiveColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: widget.activeColor.withOpacity(0.3 * heightFactor),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}

/// A circular voice indicator that wraps around the robot.
/// Shows animated rings when listening or speaking.
class RobotVoiceRings extends StatefulWidget {
  final bool isListening;
  final bool isSpeaking;
  final double volume;
  final Color color;

  const RobotVoiceRings({
    super.key,
    this.isListening = false,
    this.isSpeaking = false,
    this.volume = 0.0,
    this.color = const Color(0xFF6B4EFF),
  });

  @override
  State<RobotVoiceRings> createState() => _RobotVoiceRingsState();
}

class _RobotVoiceRingsState extends State<RobotVoiceRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isListening || widget.isSpeaking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RobotVoiceRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.isListening || widget.isSpeaking) &&
        !(oldWidget.isListening || oldWidget.isSpeaking)) {
      _controller.repeat();
    } else if (!(widget.isListening || widget.isSpeaking) &&
        (oldWidget.isListening || oldWidget.isSpeaking)) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(80, 80),
          painter: _VoiceRingsPainter(
            progress: _controller.value,
            volume: widget.volume,
            isListening: widget.isListening,
            isSpeaking: widget.isSpeaking,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _VoiceRingsPainter extends CustomPainter {
  final double progress;
  final double volume;
  final bool isListening;
  final bool isSpeaking;
  final Color color;

  _VoiceRingsPainter({
    required this.progress,
    required this.volume,
    required this.isListening,
    required this.isSpeaking,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isListening && !isSpeaking) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 4;

    // Draw 3 expanding rings
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.33) % 1.0;
      final ringRadius = maxRadius * (0.2 + phase * 0.6);
      final opacity = (1.0 - phase) * 0.5 * (0.5 + volume * 0.5);

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = color.withOpacity(opacity);

      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // Center glow pulse
    final pulsePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.1 + 0.15 * math.sin(progress * math.pi * 2))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(center, maxRadius * 0.3, pulsePaint);
  }

  @override
  bool shouldRepaint(_VoiceRingsPainter old) =>
      old.progress != progress || old.volume != volume ||
      old.isListening != isListening || old.isSpeaking != isSpeaking;
}