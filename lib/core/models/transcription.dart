class Transcription {
  final String text;
  final DateTime timestamp;
  final bool isFinal;
  final Duration elapsed; // 相对会议开始的时间

  Transcription({
    required this.text,
    required this.timestamp,
    this.isFinal = false,
    this.elapsed = Duration.zero,
  });
}
