import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/robot_state_provider.dart';
import '../widgets/robot_character.dart' show RobotCharacter, RobotExpression;
import '../widgets/robot_speech_bubble.dart';
import '../screens/chat_room_screen.dart';
import '../routes.dart';

/// A floating robot widget that sits at the bottom-right corner of the screen.
/// - Can be dragged to any position.
/// - Shows dynamic expressions based on state.
/// - Tapping opens chat or shows speech bubble.
class FloatingRobot extends StatefulWidget {
  const FloatingRobot({super.key});

  @override
  State<FloatingRobot> createState() => _FloatingRobotState();
}

class _FloatingRobotState extends State<FloatingRobot>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _showSpeechBubble = false;
  late AnimationController _bounceController;
  final double _robotSize = 60.0;
  final double _bottomMargin = 80.0;
  final double _rightMargin = 16.0;
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final robotState = context.read<RobotStateProvider>();

    if (_showSpeechBubble) {
      // If speech bubble is already showing, navigate to chat
      _navigateToChat();
      return;
    }

    // Show speech bubble with greeting
    robotState.showSpeechBubble('Ada yang bisa dibantu?');
    setState(() {
      _showSpeechBubble = true;
    });

    // After speech bubble auto-hides, reset state
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSpeechBubble = false;
        });
      }
    });
  }

  void _navigateToChat() {
    // Navigate to ChatRoomScreen
    Navigator.push(
      context,
      buildFadeSlideRoute(const ChatRoomScreen()),
    ).then((_) {
      // Reset expression when returning from chat
      if (mounted) {
        context.read<RobotStateProvider>().onAIComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final robotState = context.watch<RobotStateProvider>();

    if (!robotState.isVisible) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Initialize position based on screen size
        if (_screenSize == null) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          _position = Offset(
            _screenSize!.width - _robotSize - _rightMargin,
            _screenSize!.height - _robotSize - _bottomMargin,
          );
        }

        return Stack(
          children: [
            // Speech bubble (shown above robot)
            if (_showSpeechBubble || robotState.showSpeechBubble)
              Positioned(
                left: _position.dx - 80, // Offset to center above robot
                bottom: _position.dy + _robotSize + 8,
                child: IgnorePointer(
                  child: RobotSpeechBubble(
                    bubbleColor: const Color(0xFF2A2A3E),
                    textColor: Colors.white,
                    accentColor: const Color(0xFF6B4EFF),
                    messageInterval: const Duration(seconds: 6),
                  ),
                ),
              ),

            // Floating robot button
            Positioned(
              left: _position.dx,
              bottom: _position.dy,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() {
                    _isDragging = true;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                    // Clamp to screen bounds
                    _position = Offset(
                      _position.dx.clamp(0, (_screenSize?.width ?? 400) - _robotSize),
                      _position.dy.clamp(0, (_screenSize?.height ?? 800) - _robotSize),
                    );
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    _isDragging = false;
                  });
                  // Snap to nearest edge
                  _snapToEdge();
                },
                onTap: _handleTap,
                child: AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) {
                    final bounceY = _isDragging
                        ? 0.0
                        : (_bounceController.value - 0.5) * 4.0;

                    return Transform.translate(
                      offset: Offset(0, bounceY),
                      child: Container(
                        width: _robotSize,
                        height: _robotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6B4EFF).withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            color: const Color(0xFF1A1A2E),
                            child: RobotCharacter(
                              size: _robotSize,
                              primaryColor: const Color(0xFF6B4EFF),
                              accentColor: const Color(0xFF00CC88),
                              expression: robotState.expression,
                              isIdle: robotState.isIdle && !_isDragging,
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

  void _snapToEdge() {
    if (_screenSize == null) return;

    final screenWidth = _screenSize!.width;
    final screenHeight = _screenSize!.height;
    final midX = _position.dx + _robotSize / 2;
    final midY = _position.dy + _robotSize / 2;

    // Determine which edge is closest
    final distLeft = midX;
    final distRight = screenWidth - midX;
    final distTop = midY;
    final distBottom = screenHeight - midY;

    double newX = _position.dx;
    double newY = _position.dy;

    // Snap horizontally
    if (distLeft < distRight) {
      newX = 8; // Left edge with margin
    } else {
      newX = screenWidth - _robotSize - 8; // Right edge with margin
    }

    // Snap vertically (prefer bottom area)
    if (distBottom < distTop) {
      newY = screenHeight - _robotSize - _bottomMargin; // Bottom
    } else {
      newY = screenHeight - _robotSize - _bottomMargin; // Still prefer bottom
    }

    // Animate to snapped position
    if (mounted) {
      setState(() {
        _position = Offset(newX, newY);
      });
    }
  }
}