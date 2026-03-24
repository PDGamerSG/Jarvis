import 'package:flutter/material.dart';
import 'jarvis_service.dart';
import 'models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final JarvisService _jarvis = JarvisService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _jarvis.addListener(_onJarvisUpdate);
    _jarvis.init();
  }

  void _onJarvisUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _jarvis.removeListener(_onJarvisUpdate);
    _jarvis.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_jarvis.isThinking) _buildThinking(),
            if (_jarvis.isListening && !_jarvis.isWakeWordMode)
              _buildListening(),
            if (_jarvis.isWakeWordMode) _buildWakeWordBar(),
            if (_jarvis.isSpeaking) _buildSpeaking(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF12122A),
      elevation: 0,
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              border:
                  Border.all(color: const Color(0xFF6C63FF), width: 1.5),
            ),
            child: const Center(
              child: Text("J",
                  style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Jarvis",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(
                _jarvis.isSpeaking
                    ? "Speaking..."
                    : _jarvis.isThinking
                        ? "Thinking..."
                        : _jarvis.isWakeWordMode
                            ? "Waiting for 'Jarvis'..."
                            : _jarvis.isListening
                                ? "Listening..."
                                : _jarvis.wakeWordEnabled
                                    ? "Always on"
                                    : "Always ready",
                style: TextStyle(
                    fontSize: 11,
                    color: _jarvis.isSpeaking
                        ? const Color(0xFF6C63FF)
                        : _jarvis.isThinking
                            ? Colors.orange
                            : const Color(0xFF1D9E75)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _jarvis.wakeWordEnabled
                ? Icons.hearing
                : Icons.hearing_disabled,
            color: _jarvis.wakeWordEnabled
                ? const Color(0xFF1D9E75)
                : Colors.white38,
            size: 22,
          ),
          onPressed: _jarvis.toggleWakeWord,
          tooltip: _jarvis.wakeWordEnabled
              ? "Turn off wake word"
              : "Turn on wake word",
        ),
        if (_jarvis.isSpeaking)
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined,
                color: Color(0xFF6C63FF)),
            onPressed: _jarvis.stopSpeaking,
          ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _jarvis.messages.length,
      itemBuilder: (context, index) =>
          _buildBubble(_jarvis.messages[index]),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    return Align(
      alignment:
          msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: msg.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF1A1A3A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                  bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                ),
                border: msg.isUser
                    ? null
                    : Border.all(
                        color: const Color(0xFF6C63FF)
                            .withOpacity(0.25)),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser
                      ? Colors.white
                      : const Color(0xFFB0B8D0),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              "${msg.time.hour}:${msg.time.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(
                  fontSize: 10, color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinking() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  double opacity = (i == 0)
                      ? (_pulseAnimation.value - 0.2).clamp(0.1, 1.0)
                      : (i == 1)
                          ? _pulseAnimation.value.clamp(0.1, 1.0)
                          : (_pulseAnimation.value + 0.2)
                              .clamp(0.1, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C63FF)
                          .withOpacity(opacity),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildWakeWordBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(
                      0.2 + (_pulseAnimation.value - 1.0)),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text("Say 'Jarvis' to activate",
              style:
                  TextStyle(color: Colors.white38, fontSize: 12)),
          if (_jarvis.currentWords.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _jarvis.currentWords,
                style: const TextStyle(
                    color: Colors.white24, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListening() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1D9E75)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: const Icon(Icons.mic,
                        color: Color(0xFF1D9E75), size: 20),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Text("Listening...",
                  style: TextStyle(
                      color: Color(0xFF1D9E75), fontSize: 13)),
            ],
          ),
          if (_jarvis.currentWords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _jarvis.currentWords,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeaking() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6C63FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: const Icon(Icons.volume_up,
                    color: Color(0xFF6C63FF), size: 20),
              );
            },
          ),
          const SizedBox(width: 10),
          const Text("Jarvis is speaking...",
              style:
                  TextStyle(color: Color(0xFF6C63FF), fontSize: 13)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _jarvis.stopSpeaking,
            child: const Icon(Icons.stop_circle,
                color: Color(0xFF6C63FF), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        border:
            Border(top: BorderSide(color: Color(0xFF1E1E3A), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A3A),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF2A2A4A)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Ask Jarvis anything...",
                  hintStyle: TextStyle(
                      color: Colors.white24, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (text) {
                  _jarvis.sendMessage(text);
                  _controller.clear();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: _jarvis.isListening && !_jarvis.isWakeWordMode
                ? Icons.mic
                : Icons.mic_none,
            color: _jarvis.isListening && !_jarvis.isWakeWordMode
                ? const Color(0xFF1D9E75)
                : const Color(0xFF6C63FF),
            onTap: _jarvis.toggleListening,
            pulse: _jarvis.isListening && !_jarvis.isWakeWordMode,
          ),
          const SizedBox(width: 6),
          _buildIconButton(
            icon: Icons.send_rounded,
            color: const Color(0xFF6C63FF),
            onTap: () {
              _jarvis.sendMessage(_controller.text);
              _controller.clear();
            },
            pulse: false,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool pulse,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: pulse ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          );
        },
      ),
    );
  }
}
