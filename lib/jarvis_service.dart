import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'models.dart';

class JarvisService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool isListening = false;
  bool isWakeWordMode = false;
  bool isThinking = false;
  bool isSpeaking = false;
  bool speechEnabled = false;
  bool wakeWordEnabled = false;
  bool _isRestarting = false;
  String currentWords = '';

  final List<ChatMessage> messages = [
    ChatMessage(
      text: "Hello! I am Jarvis. Say 'Jarvis' or tap the mic to talk to me!",
      isUser: false,
      time: DateTime.now(),
    ),
  ];

  // Callback so UI can react
  Function(String)? onNewReply;

  Future<void> init() async {
    await _initTts();
    await _initSpeech();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9);

    // This reduces the audio focus beep on some devices
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
      isSpeaking = true;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      isSpeaking = false;
      notifyListeners();
      if (wakeWordEnabled) {
        Future.delayed(
          const Duration(milliseconds: 800),
          startWakeWordListening,
        );
      }
    });

    _flutterTts.setErrorHandler((msg) {
      isSpeaking = false;
      notifyListeners();
      if (wakeWordEnabled) {
        Future.delayed(
          const Duration(milliseconds: 800),
          startWakeWordListening,
        );
      }
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    isSpeaking = false;
    notifyListeners();
  }

  Future<void> _initSpeech() async {
    try {
      speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: $error');
          isListening = false;
          isWakeWordMode = false;
          notifyListeners();
          if (error.permanent) return;
          if (wakeWordEnabled && !isSpeaking) {
            Future.delayed(
              const Duration(seconds: 2),
              startWakeWordListening,
            );
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done') {
            _handleSpeechDone();
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
      speechEnabled = false;
    }
    notifyListeners();
  }

  void _handleSpeechDone() {
    final words = currentWords.toLowerCase().trim();

    if (isWakeWordMode) {
      final detected = wakeWords.firstWhere(
        (w) => words.startsWith(w),
        orElse: () => '',
      );

      if (detected.isNotEmpty) {
        final command = currentWords.substring(detected.length).trim();
        currentWords = '';
        isWakeWordMode = false;
        isListening = false;
        notifyListeners();

        if (command.isNotEmpty) {
          sendMessage(command);
        } else {
          Future.delayed(
            const Duration(milliseconds: 400),
            startCommandListening,
          );
        }
      } else {
        currentWords = '';
        isWakeWordMode = false;
        isListening = false;
        notifyListeners();
        if (wakeWordEnabled && !isSpeaking) {
          Future.delayed(
            const Duration(milliseconds: 800),
            startWakeWordListening,
          );
        }
      }
    } else {
      if (currentWords.isNotEmpty) {
        final command = currentWords;
        currentWords = '';
        isListening = false;
        notifyListeners();
        sendMessage(command);
      } else {
        isListening = false;
        notifyListeners();
        if (wakeWordEnabled && !isSpeaking) {
          Future.delayed(
            const Duration(milliseconds: 800),
            startWakeWordListening,
          );
        }
      }
    }
  }

  Future<void> startWakeWordListening() async {
    if (!speechEnabled || isSpeaking || isThinking) return;
    if (_isRestarting || !wakeWordEnabled) return;
    if (_speechToText.isListening) await _speechToText.stop();

    _isRestarting = true;
    await Future.delayed(const Duration(milliseconds: 800));
    _isRestarting = false;

    if (!wakeWordEnabled || isSpeaking || isThinking) return;

    isWakeWordMode = true;
    isListening = true;
    currentWords = '';
    notifyListeners();

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        currentWords = result.recognizedWords;
        notifyListeners();
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
    );
  }

  Future<void> startCommandListening() async {
    if (!speechEnabled || isSpeaking || isThinking) return;
    if (_speechToText.isListening) await _speechToText.stop();
    await Future.delayed(const Duration(milliseconds: 400));

    isWakeWordMode = false;
    isListening = true;
    currentWords = '';
    notifyListeners();

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        currentWords = result.recognizedWords;
        notifyListeners();
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
    );
  }

  void toggleWakeWord() {
    if (wakeWordEnabled) {
      _speechToText.stop();
      wakeWordEnabled = false;
      isWakeWordMode = false;
      isListening = false;
      currentWords = '';
      notifyListeners();
    } else {
      wakeWordEnabled = true;
      notifyListeners();
      startWakeWordListening();
    }
  }

  Future<void> toggleListening() async {
    if (isSpeaking) await stopSpeaking();

    if (isWakeWordMode || wakeWordEnabled) {
      await _speechToText.stop();
      wakeWordEnabled = false;
      isWakeWordMode = false;
      isListening = false;
      notifyListeners();
      return;
    }

    if (isListening) {
      await _speechToText.stop();
      isListening = false;
      notifyListeners();
      return;
    }

    if (!speechEnabled) {
      messages.add(ChatMessage(
        text: "Microphone not available on this device.",
        isUser: false,
        time: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

    await startCommandListening();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    messages.add(ChatMessage(
      text: text.trim(),
      isUser: true,
      time: DateTime.now(),
    ));
    isThinking = true;
    isListening = false;
    isWakeWordMode = false;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] ?? 'No reply from Jarvis.';
        isThinking = false;
        messages.add(ChatMessage(
          text: reply,
          isUser: false,
          time: DateTime.now(),
        ));
        notifyListeners();
        await speak(reply);
      } else {
        isThinking = false;
        messages.add(ChatMessage(
          text: "Jarvis returned an error (${response.statusCode}).",
          isUser: false,
          time: DateTime.now(),
        ));
        notifyListeners();
        if (wakeWordEnabled) {
          Future.delayed(
            const Duration(milliseconds: 800),
            startWakeWordListening,
          );
        }
      }
    } catch (e) {
      isThinking = false;
      messages.add(ChatMessage(
        text: "Could not reach Jarvis backend. Is the server running?",
        isUser: false,
        time: DateTime.now(),
      ));
      notifyListeners();
      if (wakeWordEnabled) {
        Future.delayed(
          const Duration(milliseconds: 800),
          startWakeWordListening,
        );
      }
    }
  }

  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }
}
