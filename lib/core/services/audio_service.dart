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
  IOSink? _fileSink;
  int _bytesWritten = 0;

  static String? _recordingsDirPath;

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Get the directory where recordings are stored. Cached after first call.
  static Future<String> getRecordingsDirPath() async {
    if (_recordingsDirPath != null) return _recordingsDirPath!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/recordings');
    await dir.create(recursive: true);
    _recordingsDirPath = dir.path;
    return _recordingsDirPath!;
  }

  /// List all local recording files, newest first.
  static Future<List<FileSystemEntity>> listRecordings() async {
    final dirPath = await getRecordingsDirPath();
    final dir = Directory(dirPath);
    final files = dir.listSync().where((f) => f.path.endsWith('.wav')).toList();
    // Cache stat results to avoid O(N log N) statSync calls in sort
    final stats = {for (final f in files) f.path: f.statSync()};
    files.sort((a, b) => stats[b.path]!.modified.compareTo(stats[a.path]!.modified));
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

    final dirPath = await getRecordingsDirPath();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentFilePath = '$dirPath/recording_$timestamp.wav';
    _bytesWritten = 0;

    // Write placeholder WAV header (44 bytes), will be updated on stop
    final file = File(_currentFilePath!);
    await file.writeAsBytes(List.filled(44, 0));
    _fileSink = file.openWrite(mode: FileMode.append);

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
      // Write to file incrementally
      _fileSink?.add(data);
      _bytesWritten += data.length;
      onAudioData(Uint8List.fromList(data));
    });
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    await _streamSub?.cancel();
    _streamSub = null;
    await _recorder.stop();
    _isRecording = false;

    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    // Update WAV header with correct data size
    if (_currentFilePath != null && _bytesWritten > 0) {
      await _updateWavHeader(_currentFilePath!, _bytesWritten, 16000, 1);
      final path = _currentFilePath;
      _currentFilePath = null;
      return path;
    }
    // No data recorded, clean up empty file
    if (_currentFilePath != null) {
      try {
        await File(_currentFilePath!).delete();
      } catch (_) {}
    }
    _currentFilePath = null;
    return null;
  }

  static Future<void> _updateWavHeader(
      String path, int dataSize, int sampleRate, int channels) async {
    final raf = await File(path).open(mode: FileMode.write);
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
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * 2, Endian.little);
    header.setUint16(32, channels * 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    await raf.setPosition(0);
    await raf.writeFrom(header.buffer.asUint8List());
    await raf.close();
  }

  Future<void> dispose() async {
    await stopRecording();
    _recorder.dispose();
  }
}
