import 'dart:typed_data';

typedef TranscriptionCallback = void Function(String text, bool isFinal);

abstract class AsrBackend {
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  });

  Future<void> sendAudio(Uint8List pcmData);

  Future<void> stopStream();
}
