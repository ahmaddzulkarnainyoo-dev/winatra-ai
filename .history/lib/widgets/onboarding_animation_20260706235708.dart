import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/robot_character.dart' show RobotCharacter, RobotExpression;

/// Fullscreen onboarding animation when user first activates "Asisten Aktif".
/// Shows robot large (200px) in center of screen with overlay, then shrinks
/// to 64px at bottom-right corner with a spring/bounce effect.
class OnboardingAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingAnimation({super.key, required this.onComplete});

  @override
  State<OnboardingAnimation> createState() => _OnboardingAnimationState();
}

class _OnboardingAnimationState extends State<OnboardingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _positionAnim;
  late Animation<double> _overlayFadeAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _bounceAnim;

  // Robot size: start at 200, end at 64
  static const double _startSize = 200.0;
  static const double _endSize = 64.0;

  // Screen position: start center, end bottom-right
  late Offset _startPosition;
  late Offset _endPosition;

  Size? _screenSize;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Scale from 200 to 64 (normalized as fraction of start size)
    _scaleAnim = Tween<double>(begin: 1.0, end: _endSize / _startSize).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOutBack),
      ),
    );

    // Position from center to bottom-right
    _positionAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    // Overlay fade out (starts after robot starts shrinking)
    _overlayFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );

    // Text fade out (text disappears as robot shrinks)
    _textFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    // Final bounce effect
    _bounceAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });

    // Listen for completion
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_screenSize == null) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          _startPosition = Offset(
            (_screenSize!.width - _startSize) / 2,
            (_screenSize!.height - _startSize) / 2,
          );
          _endPosition = Offset(
            _screenSize!.width - _endSize - 16,
            _screenSize!.height - _endSize - 80,
          );
        }

        return Stack(
          children: [
            // Dark overlay background
            AnimatedBuilder(
              animation: _overlayFadeAnim,
              builder: (context, child) {
                return Container(
                  color: Colors.black.withOpacity(0.5 * _overlayFadeAnim.value),
                );
              },
            ),

            // Text "Halo! Saya Winatra, asisten aktif Anda."
            AnimatedBuilder(
              animation: _textFadeAnim,
              builder: (context, child) {
                return Opacity(
                  opacity: _textFadeAnim.value,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: _startSize / 2 + 60,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Halo! Saya Winatra,',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Color(0xFF6B4EFF),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'asisten aktif Anda.',
                            style: TextStyle(
                              color: const Color(0xFF6B4EFF).withOpacity(0.9),
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Saya siap membantu. Ucapkan "Halo Winatra" untuk memulai.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Robot character with scale + position animation
            AnimatedBuilder(
              animation: Listenable.merge([
                _scaleAnim,
                _positionAnim,
                _bounceAnim,
              ]),
              builder: (context, child) {
                final currentSize = _startSize * _scaleAnim.value;
                final bounceOffset = _bounceAnim.value > 0.99
                    ? (1.0 - _bounceAnim.value) * 20
                    : (_bounceAnim.value > 0.0
                        ? math.sin(_bounceAnim.value * math.pi * 3) * 8 * (1.0 - _bounceAnim.value)
                        : 0.0);

                // Interpolate position from center to bottom-right
                final progress = (_controller.value - 0.3) / 0.55; // 0.3 to 0.85
                final clampedProgress = progress.clamp(0.0, 1.0);
                final currentX = _startPosition.dx +
                    (_endPosition.dx - _startPosition.dx) * clampedProgress;
                final currentY = _startPosition.dy +
                    (_endPosition.dy - _startPosition.dy) * clampedProgress;

                return Positioned(
                  left: currentX,
                  top: currentY + bounceOffset,
                  child: SizedBox(
                    width: currentSize,
                    height: currentSize,
                    child: Stack(
                      children: [
                        // Glow ring around robot
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6B4EFF).withOpacity(
                                  0.4 * (1.0 - clampedProgress * 0.5),
                                ),
                                blurRadius: 20 + (1.0 - clampedProgress) * 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        // Robot character
                        Center(
                          child: RobotCharacter(
                            size: currentSize * 0.85,
                            primaryColor: const Color(0xFF6B4EFF),
                            accentColor: const Color(0xFF00CC88),
                            expression: RobotExpression.happy,
                            isIdle: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}