import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _streamSub;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording({
    required void Function(Uint8List pcmData) onAudioData,
  }) async {
    if (_isRecording) return;
    final hasPerms = await _recorder.hasPermission();
    if (!hasPerms) throw Exception('Microphone permission denied');

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _isRecording = true;
    _streamSub = stream.listen((data) {
      onAudioData(Uint8List.fromList(data));
    });
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    await _streamSub?.cancel();
    _streamSub = null;
    await _recorder.stop();
    _isRecording = false;
  }

  void dispose() {
    stopRecording();
    _recorder.dispose();
  }
}
