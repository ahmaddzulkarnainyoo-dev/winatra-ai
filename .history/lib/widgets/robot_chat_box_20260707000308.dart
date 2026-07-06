import 'package:flutter/material.dart';

/// A speech bubble / chat box that appears above the robot.
/// Displays AI responses, command results, and can be scrolled if long.
/// Auto-hides after 10 seconds or on tap.
class RobotChatBox extends StatefulWidget {
  final String text;
  final Color bubbleColor;
  final Color textColor;
  final Color accentColor;
  final VoidCallback? onDismiss;

  const RobotChatBox({
    super.key,
    required this.text,
    this.bubbleColor = const Color(0xFF2A2A3E),
    this.textColor = Colors.white,
    this.accentColor = const Color(0xFF6B4EFF),
    this.onDismiss,
  });

  @override
  State<RobotChatBox> createState() => _RobotChatBoxState();
}

class _RobotChatBoxState extends State<RobotChatBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 20),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 280,
              maxHeight: 200,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        color: widget.textColor.withOpacity(0.95),
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
                // Tail pointing down
                Positioned(
                  left: 20,
                  bottom: -8,
                  child: ClipPath(
                    clipper: _ChatBoxTailClipper(),
                    child: Container(
                      width: 16,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.bubbleColor,
                        border: Border(
                          left: BorderSide(
                            color: widget.accentColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                          bottom: BorderSide(
                            color: widget.accentColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Close button (small X)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: widget.textColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBoxTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ChatBoxTailClipper old) => false;
}