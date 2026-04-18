import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _streamSub;
  bool _isRecording = false;
  String? _currentFilePath;
  final List<int> _pcmBuffer = [];

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Get the directory where recordings are stored.
  static Future<Directory> getRecordingsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/recordings');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// List all local recording files, newest first.
  static Future<List<FileSystemEntity>> listRecordings() async {
    final dir = await getRecordingsDir();
    final files = dir.listSync().where((f) => f.path.endsWith('.wav')).toList();
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  Future<void> startRecording({
    required void Function(Uint8List pcmData) onAudioData,
    bool echoCancel = false,
    bool autoGain = false,
  }) async {
    if (_isRecording) return;
    final hasPerms = await _recorder.hasPermission();
    if (!hasPerms) throw Exception('Microphone permission denied');

    _pcmBuffer.clear();
    final dir = await getRecordingsDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = '${dir.path}/recording_$timestamp.wav';

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: echoCancel,
        autoGain: autoGain,
      ),
    );

    _isRecording = true;
    _streamSub = stream.listen((data) {
      _pcmBuffer.addAll(data);
      onAudioData(Uint8List.fromList(data));
    });
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    await _streamSub?.cancel();
    _streamSub = null;
    await _recorder.stop();
    _isRecording = false;

    // Save PCM buffer as WAV file
    if (_currentFilePath != null && _pcmBuffer.isNotEmpty) {
      await _writeWav(_currentFilePath!, _pcmBuffer, 16000, 1);
      final path = _currentFilePath;
      _pcmBuffer.clear();
      _currentFilePath = null;
      return path;
    }
    _pcmBuffer.clear();
    _currentFilePath = null;
    return null;
  }

  static Future<void> _writeWav(
      String path, List<int> pcmData, int sampleRate, int channels) async {
    final dataSize = pcmData.length;
    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * 2, Endian.little); // byte rate
    header.setUint16(32, channels * 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final file = File(path);
    await file.writeAsBytes([...header.buffer.asUint8List(), ...pcmData]);
  }

  void dispose() {
    stopRecording();
    _recorder.dispose();
  }
}
