import 'dart:typed_data';
import '../../constants.dart';
import 'asr_backend.dart';
import 'cloud_asr.dart';
import 'sherpa_asr.dart';

class AsrRouter implements AsrBackend {
  final CloudAsr _cloud;
  final SherpaAsr _sherpa;
  AsrMode mode;
  AsrBackend? _active;

  AsrRouter({
    required CloudAsr cloud,
    required SherpaAsr sherpa,
    this.mode = AsrMode.cloud,
  })  : _cloud = cloud,
        _sherpa = sherpa;

  AsrBackend get _backend => mode == AsrMode.local ? _sherpa : _cloud;

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) {
    _active = _backend;
    return _active!.startStream(
      sessionId: sessionId,
      onTranscription: onTranscription,
      onError: onError,
    );
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) {
    return _active?.sendAudio(pcmData) ?? Future.value();
  }

  @override
  Future<void> stopStream() async {
    await _active?.stopStream();
    _active = null;
  }
}
