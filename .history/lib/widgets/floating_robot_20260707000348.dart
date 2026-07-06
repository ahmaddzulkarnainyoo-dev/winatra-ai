import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/robot_state_provider.dart';
import '../providers/assistant_state_provider.dart';
import '../providers/voice_provider.dart';
import '../services/voice_command_service.dart';
import '../widgets/robot_character.dart' show RobotCharacter, RobotExpression;
import '../widgets/robot_chat_box.dart';
import '../widgets/voice_indicator.dart';
import '../widgets/onboarding_animation.dart';
import '../screens/chat_room_screen.dart';
import '../routes.dart';

/// A floating robot widget that sits at the bottom-right corner of the screen.
/// Integrates: onboarding, voice indicators, chat box, hide/show, expressions.
class FloatingRobot extends StatefulWidget {
  const FloatingRobot({super.key});

  @override
  State<FloatingRobot> createState() => _FloatingRobotState();
}

class _FloatingRobotState extends State<FloatingRobot>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  bool _showChatBox = false;
  String _chatBoxText = '';
  late AnimationController _bounceController;
  final double _robotSize = 60.0;
  final double _bottomMargin = 80.0;
  final double _rightMargin = 16.0;
  Size? _screenSize;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Listen for assistant state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding();
    });
  }

  void _checkOnboarding() {
    final assistant = context.read<AssistantActiveProvider>();
    if (assistant.isActive && !assistant.hasSeenOnboarding) {
      setState(() {
        _showOnboarding = true;
      });
    }

    // Listen for speech bubble / chat box updates
    final robotState = context.read<RobotStateProvider>();
    robotState.addListener(_onRobotStateChanged);
  }

  void _onRobotStateChanged() {
    if (!mounted) return;
    final robotState = context.read<RobotStateProvider>();
    if (robotState.showSpeechBubble && robotState.speechText.isNotEmpty) {
      setState(() {
        _showChatBox = true;
        _chatBoxText = robotState.speechText;
      });
    } else {
      setState(() {
        _showChatBox = false;
        _chatBoxText = '';
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    // Remove listener
    try {
      context.read<RobotStateProvider>().removeListener(_onRobotStateChanged);
    } catch (_) {}
    super.dispose();
  }

  void _handleTap() {
    final robotState = context.read<RobotStateProvider>();
    final assistant = context.read<AssistantActiveProvider>();
    final voiceProvider = context.read<VoiceProvider>();

    if (_showChatBox) {
      // If chat box is showing, dismiss it
      robotState.hideSpeechBubble();
      return;
    }

    // Check if voice is active and assistant is active
    if (assistant.isActive && assistant.isVoiceEnabled) {
      // Trigger voice input
      final voiceCommand = VoiceCommandService();
      if (!voiceCommand.isProcessing) {
        voiceCommand.startVoiceInput();
        return;
      }
    }

    // Default: show greeting
    robotState.displaySpeechBubble('Ada yang bisa dibantu?');
  }

  void _onLongPress() {
    // Show hide/settings menu
    _showHideMenu();
  }

  void _showHideMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Opsi Robot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.visibility_off,
                      color: const Color(0xFF6B4EFF), size: 24),
                  title: const Text(
                    'Sembunyikan',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Robot akan disembunyikan dari layar',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await context.read<AssistantActiveProvider>().hideRobot();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Robot disembunyikan. Tap dua kali pojok kanan bawah untuk menampilkan.',
                          ),
                          backgroundColor: Color(0xFF6B4EFF),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                const Divider(color: Color(0xFF333355)),
                ListTile(
                  leading: Icon(Icons.settings,
                      color: const Color(0xFF6B4EFF), size: 24),
                  title: const Text(
                    'Pengaturan Asisten',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Atur suara, onboarding, dan lainnya',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings
                  },
                ),
                const Divider(color: Color(0xFF333355)),
                ListTile(
                  leading: Icon(Icons.chat,
                      color: const Color(0xFF6B4EFF), size: 24),
                  title: const Text(
                    'Buka Chat',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Chat dengan Winatra AI',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToChat();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      buildFadeSlideRoute(const ChatRoomScreen()),
    ).then((_) {
      if (mounted) {
        context.read<RobotStateProvider>().onAIComplete();
      }
    });
  }

  void _onDoubleTap() {
    final assistant = context.read<AssistantActiveProvider>();
    if (assistant.isRobotHidden) {
      assistant.showRobot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Robot ditampilkan kembali'),
            backgroundColor: Color(0xFF6B4EFF),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final robotState = context.watch<RobotStateProvider>();
    final assistant = context.watch<AssistantActiveProvider>();
    final voiceProvider = context.watch<VoiceProvider>();

    // Check if we should show onboarding
    if (_showOnboarding) {
      return OnboardingAnimation(
        onComplete: () {
          setState(() {
            _showOnboarding = false;
          });
          context.read<AssistantActiveProvider>().markOnboardingSeen();
        },
      );
    }

    // If assistant is not active or robot is hidden, show nothing
    if (!assistant.isActive || assistant.isRobotHidden) {
      // Still detect double-tap to show robot
      return GestureDetector(
        onDoubleTap: _onDoubleTap,
        child: const SizedBox.expand(),
      );
    }

    // If robot is not visible in state, shrink
    if (!robotState.isVisible) {
      return const SizedBox.shrink();
    }

    final isListening = voiceProvider.isListening;
    final isSpeaking = voiceProvider.isSpeaking;
    final speechVolume = voiceProvider.speechVolume;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_screenSize == null) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          _position = Offset(
            _screenSize!.width - _robotSize - _rightMargin,
            _screenSize!.height - _robotSize - _bottomMargin,
          );
        }

        return Stack(
          children: [
            // Double-tap area (full screen) to show hidden robot
            if (assistant.isRobotHidden)
              GestureDetector(
                onDoubleTap: _onDoubleTap,
                child: const SizedBox.expand(),
              ),

            // Chat box (shown above robot)
            if (_showChatBox && _chatBoxText.isNotEmpty)
              Positioned(
                left: _position.dx - 80,
                bottom: _position.dy + _robotSize + 16,
                child: IgnorePointer(
                  ignoring: false,
                  child: RobotChatBox(
                    text: _chatBoxText,
                    bubbleColor: const Color(0xFF2A2A3E),
                    textColor: Colors.white,
                    accentColor: const Color(0xFF6B4EFF),
                    onDismiss: () {
                      robotState.hideSpeechBubble();
                    },
                  ),
                ),
              ),

            // Voice indicators (sound waves around robot)
            if (isListening || isSpeaking)
              Positioned(
                left: _position.dx - 10,
                bottom: _position.dy - 10,
                child: RobotVoiceRings(
                  isListening: isListening,
                  isSpeaking: isSpeaking,
                  volume: speechVolume,
                  color: isListening
                      ? const Color(0xFFFFCC00)
                      : const Color(0xFFFF6600),
                ),
              ),

            // Voice wave bars below robot
            if (isListening || isSpeaking)
              Positioned(
                left: _position.dx + _robotSize / 2 - 20,
                bottom: _position.dy - 16,
                child: VoiceIndicator(
                  isActive: true,
                  volume: speechVolume,
                  activeColor: isListening
                      ? const Color(0xFFFFCC00)
                      : const Color(0xFFFF6600),
                  barCount: 5,
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
                      _position.dx.clamp(
                          0, (_screenSize?.width ?? 400) - _robotSize),
                      _position.dy.clamp(
                          0, (_screenSize?.height ?? 800) - _robotSize),
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
                onLongPress: _onLongPress,
                onDoubleTap: _onDoubleTap,
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
                              color: isListening
                                  ? const Color(0xFFFFCC00).withOpacity(0.4)
                                  : isSpeaking
                                      ? const Color(0xFFFF6600).withOpacity(0.4)
                                      : const Color(0xFF6B4EFF).withOpacity(0.3),
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
                              accentColor: isListening
                                  ? const Color(0xFFFFCC00)
                                  : isSpeaking
                                      ? const Color(0xFFFF6600)
                                      : const Color(0xFF00CC88),
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