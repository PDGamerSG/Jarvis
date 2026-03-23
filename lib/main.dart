import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const JarvisApp());
}

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jarvis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF1D9E75),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, required this.time});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hello! I am Jarvis. Tap the mic and speak to me!",
      isUser: false,
      time: DateTime.now(),
    ),
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _speechEnabled = false;
  String _currentWords = '';

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
    _initSpeech();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);  // natural conversational speed
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9);       // slightly deeper = more Jarvis-like

    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (!mounted) return;
    setState(() => _isSpeaking = false);
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          if (!mounted) return;
          setState(() => _isListening = false);
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done') {
            if (!mounted) return;
            if (_currentWords.isNotEmpty) {
              final words = _currentWords;
              setState(() {
                _currentWords = '';
                _isListening = false;
              });
              _sendMessage(words);
            } else {
              setState(() => _isListening = false);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
      _speechEnabled = false;
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    FocusScope.of(context).unfocus();

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text.trim(),
        isUser: true,
        time: DateTime.now(),
      ));
      _isThinking = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text.trim()}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] ?? 'No reply from Jarvis.';

        setState(() {
          _isThinking = false;
          _messages.add(ChatMessage(
            text: reply,
            isUser: false,
            time: DateTime.now(),
          ));
        });

        // Speak the reply out loud
        await _speak(reply);

      } else {
        setState(() {
          _isThinking = false;
          _messages.add(ChatMessage(
            text: "Jarvis returned an error (${response.statusCode}). Please try again.",
            isUser: false,
            time: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _messages.add(ChatMessage(
          text: "Could not reach Jarvis backend. Is the server running?",
          isUser: false,
          time: DateTime.now(),
        ));
      });
    }
    _scrollToBottom();
  }

  Future<void> _toggleListening() async {
    // Stop Jarvis speaking before listening
    if (_isSpeaking) await _stopSpeaking();

    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    if (!_speechEnabled) {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: "Microphone not available on this device.",
          isUser: false,
          time: DateTime.now(),
        ));
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isListening = true;
      _currentWords = '';
    });

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        setState(() => _currentWords = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      localeId: 'en_US',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                border: Border.all(
                    color: const Color(0xFF6C63FF), width: 1.5),
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
                  _isSpeaking
                      ? "Speaking..."
                      : _isListening
                          ? "Listening..."
                          : _isThinking
                              ? "Thinking..."
                              : "Always ready",
                  style: TextStyle(
                      fontSize: 11,
                      color: _isSpeaking
                          ? const Color(0xFF6C63FF)
                          : _isListening
                              ? const Color(0xFF1D9E75)
                              : _isThinking
                                  ? Colors.orange
                                  : const Color(0xFF1D9E75)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Color(0xFF6C63FF)),
              onPressed: _stopSpeaking,
              tooltip: 'Stop speaking',
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _buildBubble(_messages[index]),
              ),
            ),
            if (_isThinking) _buildThinking(),
            if (_isListening) _buildListening(),
            if (_isSpeaking) _buildSpeaking(),
            _buildInputBar(),
          ],
        ),
      ),
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

  Widget _buildListening() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const Text("Listening... speak now",
                  style: TextStyle(
                      color: Color(0xFF1D9E75), fontSize: 13)),
            ],
          ),
          if (_currentWords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _currentWords,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              style: TextStyle(color: Color(0xFF6C63FF), fontSize: 13)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _stopSpeaking,
            child: const Icon(Icons.stop_circle,
                color: Color(0xFF6C63FF), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF12122A),
        border: Border(
            top: BorderSide(color: Color(0xFF1E1E3A), width: 1)),
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
                  hintStyle:
                      TextStyle(color: Colors.white24, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: _isListening ? Icons.mic : Icons.mic_none,
            color: _isListening
                ? const Color(0xFF1D9E75)
                : const Color(0xFF6C63FF),
            onTap: _toggleListening,
            pulse: _isListening,
          ),
          const SizedBox(width: 6),
          _buildIconButton(
            icon: Icons.send_rounded,
            color: const Color(0xFF6C63FF),
            onTap: () => _sendMessage(_controller.text),
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
