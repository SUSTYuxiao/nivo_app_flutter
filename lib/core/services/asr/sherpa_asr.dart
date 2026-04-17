import 'dart:typed_data';
import 'asr_backend.dart';

class SherpaAsr implements AsrBackend {
  bool _isStreaming = false;
  // ignore: unused_field — will be used when sherpa_onnx integration is implemented
  TranscriptionCallback? _onTranscription;

  Future<bool> isModelDownloaded(String modelId) async {
    // Check sherpa_onnx model files existence - to be implemented when model download is ready
    return false;
  }

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) async {
    _isStreaming = true;
    _onTranscription = onTranscription;
    // sherpa_onnx recognizer initialization will be implemented after model download feature
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) async {
    if (!_isStreaming) return;
    // Feed PCM data to sherpa_onnx recognizer
    // Results delivered via _onTranscription callback
  }

  @override
  Future<void> stopStream() async {
    _isStreaming = false;
    _onTranscription = null;
  }
}
