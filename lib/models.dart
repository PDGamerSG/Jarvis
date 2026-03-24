class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

const List<String> wakeWords = [
  'jarvis',
  'hey jarvis',
  'ok jarvis',
  'okay jarvis',
];
