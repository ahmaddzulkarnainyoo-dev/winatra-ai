import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bubble_state_provider.dart';
import '../widgets/robot_character.dart' show RobotCharacter, RobotExpression;
import 'mini_chat_overlay.dart';

/// A floating chat bubble (like Google AI / Facebook Messenger) that sits
/// at the bottom-right corner. Uses RobotCharacter with dynamic expressions.
/// Tapping opens MiniChatOverlay instead of navigating to a new page.
class FloatingBubble extends StatefulWidget {
  const FloatingBubble({super.key});

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  late AnimationController _bounceController;
  final double _bubbleSize = 56.0;
  final double _bottomMargin = 80.0;
  final double _rightMargin = 16.0;
  Size? _screenSize;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _openMiniChat() {
    // Set robot to happy when opening
    context.read<BubbleStateProvider>().resetToHappy();

    _overlayEntry = OverlayEntry(
      builder: (context) => MiniChatOverlay(
        onClose: () {
          _removeOverlay();
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleState = context.watch<BubbleStateProvider>();

    if (!bubbleState.isVisible) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_screenSize == null) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          _position = Offset(
            _screenSize!.width - _bubbleSize - _rightMargin,
            _screenSize!.height - _bubbleSize - _bottomMargin,
          );
        }

        return Stack(
          children: [
            // Floating bubble
            Positioned(
              left: _position.dx,
              bottom: _position.dy,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() => _isDragging = true);
                },
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                    _position = Offset(
                      _position.dx.clamp(
                          0, (_screenSize?.width ?? 400) - _bubbleSize),
                      _position.dy.clamp(
                          0, (_screenSize?.height ?? 800) - _bubbleSize),
                    );
                  });
                },
                onPanEnd: (_) {
                  setState(() => _isDragging = false);
                  _snapToEdge();
                },
                onTap: _openMiniChat,
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) {
                    final bounceY = _isDragging
                        ? 0.0
                        : (_bounceController.value - 0.5) * 4.0;

                    return Transform.translate(
                      offset: Offset(0, bounceY),
                      child: Container(
                        width: _bubbleSize,
                        height: _bubbleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6B4EFF),
                          boxShadow: [
                            BoxShadow(
                              color: bubbleState.expression ==
                                      RobotExpression.thinking
                                  ? const Color(0xFF66B2FF).withOpacity(0.5)
                                  : bubbleState.expression ==
                                          RobotExpression.excited
                                      ? const Color(0xFFFF6600).withOpacity(0.5)
                                      : const Color(0xFF6B4EFF).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: const Color(0xFF1A1A2E),
                            child: RobotCharacter(
                              size: _bubbleSize * 0.82,
                              primaryColor: const Color(0xFF6B4EFF),
                              accentColor: _getAccentColor(bubbleState.expression),
                              expression: bubbleState.expression,
                              isIdle: bubbleState.isIdle && !_isDragging,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getAccentColor(RobotExpression exp) {
    switch (exp) {
      case RobotExpression.thinking:
      case RobotExpression.processing:
        return const Color(0xFF66B2FF);
      case RobotExpression.excited:
        return const Color(0xFFFF6600);
      case RobotExpression.sleepy:
        return const Color(0xFF8888AA);
      default:
        return const Color(0xFF00CC88);
    }
  }

  void _snapToEdge() {
    if (_screenSize == null) return;

    final screenWidth = _screenSize!.width;
    final screenHeight = _screenSize!.height;
    final midX = _position.dx + _bubbleSize / 2;
    final midY = _position.dy + _bubbleSize / 2;

    final distLeft = midX;
    final distRight = screenWidth - midX;
    final distTop = midY;
    final distBottom = screenHeight - midY;

    double newX = _position.dx;
    double newY = _position.dy;

    // Snap horizontally
    if (distLeft < distRight) {
      newX = 8;
    } else {
      newX = screenWidth - _bubbleSize - 8;
    }

    // Snap vertically (prefer bottom area)
    if (distBottom < distTop) {
      newY = screenHeight - _bubbleSize - _bottomMargin;
    } else {
      newY = screenHeight - _bubbleSize - _bottomMargin;
    }

    if (mounted) {
      setState(() {
        _position = Offset(newX, newY);
      });
    }
  }
}