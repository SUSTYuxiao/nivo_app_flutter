class Transcription {
  final String text;
  final DateTime timestamp;
  final bool isFinal;

  Transcription({
    required this.text,
    required this.timestamp,
    this.isFinal = false,
  });
}
