import 'dart:io';
import 'dart:typed_data';
import '../../constants.dart';
import 'asr_backend.dart';
import 'cloud_asr.dart';
import 'ios_asr.dart';
import 'sherpa_asr.dart';

class AsrRouter implements AsrBackend {
  final CloudAsr _cloud;
  final SherpaAsr _sherpa;
  final IosAsr _iosAsr;
  AsrMode mode;
  bool useNivoTranscription;
  AsrBackend? _active;

  AsrRouter({
    required CloudAsr cloud,
    required SherpaAsr sherpa,
    IosAsr? iosAsr,
    this.mode = AsrMode.auto,
    this.useNivoTranscription = false,
  })  : _cloud = cloud,
        _sherpa = sherpa,
        _iosAsr = iosAsr ?? IosAsr();

  AsrBackend get _backend {
    if (mode == AsrMode.auto && useNivoTranscription) {
      return _cloud;
    }
    // Auto (no Nivo) or Local: use platform-native ASR
    return Platform.isIOS ? _iosAsr : _sherpa;
  }

  /// Whether the active backend captures audio directly (no need to feed PCM).
  bool get activeBackendCapturesAudio => _active is IosAsr;

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) {
    _active = _backend;
    if (_active is IosAsr) {
      return (_active as IosAsr).startStream(
        sessionId: sessionId,
        onTranscription: onTranscription,
        onError: onError,
        onDevice: mode == AsrMode.local,
      );
    }
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
