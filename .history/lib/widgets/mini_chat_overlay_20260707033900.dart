import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bubble_state_provider.dart';
import '../providers/brain_provider.dart';
import '../services/ai_service.dart';
import '../services/rag_service.dart';
import '../widgets/robot_character.dart' show RobotCharacter, RobotExpression;

/// Mini Chat Overlay (Google AI style) that appears when floating bubble is tapped.
/// Shows a bottom sheet with chat interface, auto-focuses keyboard.
class MiniChatOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const MiniChatOverlay({super.key, required this.onClose});

  @override
  State<MiniChatOverlay> createState() => _MiniChatOverlayState();
}

class _MiniChatOverlayState extends State<MiniChatOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];

  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _slideController.forward();

    // Auto-focus keyboard after overlay shows
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    // Set bubble expression to happy
    context.read<BubbleStateProvider>().resetToHappy();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isProcessing = true;
    });
    _controller.clear();

    // Capture provider reference BEFORE try block to avoid naming conflict with String context variable
    final bubbleProvider = context.read<BubbleStateProvider>();

    // Set robot to thinking
    bubbleProvider.setThinking();

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Search The Brain for context
      String context = '';
      try {
        context = await RAGService.searchAllDocuments(text);
      } catch (_) {}

      // Get AI response
      final aiService = AIService();
      String answer;

      if (context.isNotEmpty) {
        answer = await aiService.generateAnswer(
          query: text,
          isOffline: false,
          context: context,
        );
      } else {
        answer = await aiService.chat(
          message: text,
          isOffline: false,
        );
      }

      // Set robot to excited (use captured provider, NOT context.read which conflicts with String context)
      bubbleProvider.setExcited();

      setState(() {
        _messages.add({'role': 'ai', 'text': answer});
        _isProcessing = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': 'Maaf, terjadi kesalahan. Silakan coba lagi.',
        });
        _isProcessing = false;
      });
      bubbleProvider.resetToHappy();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleState = context.watch<BubbleStateProvider>();

    return GestureDetector(
      onTap: widget.onClose,
      child: AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {}, // Prevent close when tapping on card
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      height: 440,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Header
                          _buildHeader(bubbleState),
                          const Divider(
                            color: Color(0xFF333355),
                            height: 1,
                          ),
                          // Chat messages
                          Expanded(child: _buildChatMessages()),
                          // Input area
                          _buildInput(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BubbleStateProvider bubbleState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Robot character in header
          SizedBox(
            width: 36,
            height: 36,
            child: RobotCharacter(
              size: 36,
              primaryColor: const Color(0xFF6B4EFF),
              accentColor: const Color(0xFF00CC88),
              expression: bubbleState.expression,
              isIdle: bubbleState.isIdle,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tanya Winatra',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _isProcessing ? 'Sedang berpikir...' : 'Online',
                style: TextStyle(
                  color: _isProcessing
                      ? const Color(0xFF66B2FF)
                      : const Color(0xFF00CC88),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF8888AA)),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Colors.white.withOpacity(0.15),
            ),
            const SizedBox(height: 12),
            Text(
              'Ada yang ingin ditanyakan?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isProcessing) {
          return _buildTypingIndicator();
        }

        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final text = msg['text'] ?? '';

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF6B4EFF).withOpacity(0.3)
                  : const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: isUser ? const Radius.circular(6) : null,
                bottomRight: !isUser ? const Radius.circular(6) : null,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFFEBEBF5),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: const Radius.circular(6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0),
            const SizedBox(width: 4),
            _dot(1),
            const SizedBox(width: 4),
            _dot(2),
          ],
        ),
      ),
    );
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6B4EFF).withOpacity(0.5 + index * 0.2),
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16162A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ketik pertanyaan...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A3E),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF6B4EFF),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6B4EFF),
              ),
              child: Icon(
                _isProcessing ? Icons.hourglass_empty : Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}