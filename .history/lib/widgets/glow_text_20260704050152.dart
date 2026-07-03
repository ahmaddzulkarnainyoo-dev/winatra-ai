import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A text widget with a slow pulsing glow animation.
/// The text cycles between its base color and a bright white glow.
class GlowText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color glowColor;
  final Duration duration;

  const GlowText({
    super.key,
    required this.text,
    this.style,
    this.glowColor = const Color(0xFF9B7EFF),
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<GlowText> createState() => _GlowTextState();
}

class _GlowTextState extends State<GlowText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final glowValue = _animation.value; // 0.0 → 1.0 → 0.0
        // Map 0..1 to 0.3..1.0 opacity for the glow layer
        final glowOpacity = 0.3 + (glowValue * 0.7);
        // Map 0..1 to 0.6..1.0 for the base text brightness
        final textOpacity = 0.6 + (glowValue * 0.4);

        return Stack(
          children: [
            // Glow layer
            Text(
              widget.text,
              style: (widget.style ?? const TextStyle()).copyWith(
                color: widget.glowColor.withOpacity(glowOpacity * 0.5),
                shadows: [
                  Shadow(
                    color: widget.glowColor.withOpacity(glowOpacity * 0.6),
                    blurRadius: 8 + (glowValue * 16),
                  ),
                  Shadow(
                    color: widget.glowColor.withOpacity(glowOpacity * 0.3),
                    blurRadius: 20 + (glowValue * 24),
                  ),
                ],
              ),
            ),
            // Base text
            Text(
              widget.text,
              style: (widget.style ?? const TextStyle()).copyWith(
                color: widget.glowColor.withOpacity(textOpacity),
              ),
            ),
          ],
        );
      },
    );
  }
}