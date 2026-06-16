import 'package:flutter/material.dart';

class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double pressedScale;

  const AnimatedPressable({
    Key? key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 120),
    this.pressedScale = 0.96,
  }) : super(key: key);

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _pressed = false;

  void _updatePressed(bool pressed) {
    setState(() {
      _pressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _updatePressed(true),
      onTapUp: (_) {
        _updatePressed(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _updatePressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
