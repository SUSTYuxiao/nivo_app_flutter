import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'asr_backend.dart';
import 'asr_models.dart';

class SherpaAsr implements AsrBackend {
  String? _modelsRoot;
  final Dio _dio;
  bool _isStreaming = false;
  TranscriptionCallback? _onTranscription;

  // Accumulate PCM chunks during streaming, transcribe on stop
  final List<int> _pcmBuffer = [];

  SherpaAsr({Dio? dio}) : _dio = dio ?? Dio();

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _modelsRoot = '${appDir.path}/models';
    await Directory(_modelsRoot!).create(recursive: true);
  }

  String get modelsRoot {
    if (_modelsRoot == null) {
      throw StateError('SherpaAsr not initialised. Call init() first.');
    }
    return _modelsRoot!;
  }

  String _modelDir(String modelId) => '$modelsRoot/$modelId';

  AsrModelInfo _findModel(String modelId) =>
      kAsrModels.firstWhere((m) => m.id == modelId,
          orElse: () => kAsrModels.first);

  /// Check if a specific model is downloaded.
  Future<bool> isModelDownloaded([String modelId = 'paraformer-zh']) async {
    if (_modelsRoot == null) return false;
    final model = _findModel(modelId);
    final dir = _modelDir(modelId);
    for (final file in model.files) {
      if (!await File('$dir/$file').exists()) return false;
    }
    return true;
  }

  /// Download a specific model. Yields progress (0.0 - 1.0).
  Stream<double> downloadModel([String modelId = 'paraformer-zh']) async* {
    final model = _findModel(modelId);
    final dir = _modelDir(modelId);
    await Directory(dir).create(recursive: true);

    final filesToDownload = <String>[];
    for (final file in model.files) {
      if (!await File('$dir/$file').exists()) {
        filesToDownload.add(file);
      }
    }

    if (filesToDownload.isEmpty) {
      yield 1.0;
      return;
    }

    int downloadedFiles = 0;

    for (final file in filesToDownload) {
      final savePath = '$dir/$file';
      await File(savePath).parent.create(recursive: true);

      await _dio.download(
        '${model.baseUrl}/$file',
        savePath,
        onReceiveProgress: (received, total) {
          final fileProgress = total > 0 ? received / total : 0.5;
          _lastProgress =
              (downloadedFiles + fileProgress) / filesToDownload.length;
        },
      );
      downloadedFiles++;
      _lastProgress = downloadedFiles / filesToDownload.length;
      yield _lastProgress;
    }
  }

  double _lastProgress = 0.0;
  double get downloadProgress => _lastProgress;

  /// Delete a downloaded model to free space.
  Future<void> deleteModel(String modelId) async {
    final dir = Directory(_modelDir(modelId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // --- AsrBackend streaming interface ---

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) async {
    _isStreaming = true;
    _onTranscription = onTranscription;
    _pcmBuffer.clear();
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) async {
    if (!_isStreaming) return;
    _pcmBuffer.addAll(pcmData);
  }

  @override
  Future<void> stopStream() async {
    if (!_isStreaming) return;
    _isStreaming = false;

    if (_pcmBuffer.isNotEmpty &&
        _onTranscription != null &&
        _modelsRoot != null) {
      try {
        const modelId = 'paraformer-zh';
        if (await isModelDownloaded(modelId)) {
          final dir = _modelDir(modelId);
          final model = _findModel(modelId);

          // Convert PCM16 bytes to float samples
          final bytes = Uint8List.fromList(_pcmBuffer);
          final samples = Float32List(bytes.length ~/ 2);
          for (var i = 0; i < samples.length; i++) {
            final sample = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
            samples[i] =
                (sample < 32768 ? sample : sample - 65536) / 32768.0;
          }

          final text = await Isolate.run(
            () => _transcribeInIsolate(samples, dir, model.modelType),
          );

          if (text.isNotEmpty) {
            _onTranscription!(text, true);
          }
        }
      } catch (_) {
        // Silently fail - cloud ASR is the fallback
      }
    }

    _pcmBuffer.clear();
    _onTranscription = null;
  }

  /// Transcribe a WAV file using the specified model (for non-streaming use).
  Future<String> transcribe(String audioPath,
      {String modelId = 'paraformer-zh'}) async {
    if (!await isModelDownloaded(modelId)) {
      throw StateError('Model $modelId not downloaded.');
    }
    final dir = _modelDir(modelId);
    final model = _findModel(modelId);
    return Isolate.run(
        () => _transcribeFileInIsolate(audioPath, dir, model.modelType));
  }

  static String _transcribeInIsolate(
      Float32List samples, String modelDir, AsrModelType modelType) {
    sherpa.initBindings();
    final config = _buildConfig(modelDir, modelType);
    final recognizer = sherpa.OfflineRecognizer(config);
    final stream = recognizer.createStream();

    stream.acceptWaveform(samples: samples, sampleRate: 16000);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;

    stream.free();
    recognizer.free();
    return text;
  }

  static String _transcribeFileInIsolate(
      String audioPath, String modelDir, AsrModelType modelType) {
    sherpa.initBindings();
    final config = _buildConfig(modelDir, modelType);
    final recognizer = sherpa.OfflineRecognizer(config);
    final stream = recognizer.createStream();

    final wave = sherpa.readWave(audioPath);
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    recognizer.decode(stream);
    final text = recognizer.getResult(stream).text;

    stream.free();
    recognizer.free();
    return text;
  }

  static sherpa.OfflineRecognizerConfig _buildConfig(
      String modelDir, AsrModelType modelType) {
    switch (modelType) {
      case AsrModelType.paraformer:
        return sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            paraformer: sherpa.OfflineParaformerModelConfig(
              model: '$modelDir/model.int8.onnx',
            ),
            tokens: '$modelDir/tokens.txt',
            numThreads: 2,
            debug: false,
            modelType: 'paraformer',
          ),
        );
      case AsrModelType.qwen3:
        return sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            qwen3Asr: sherpa.OfflineQwen3AsrModelConfig(
              convFrontend: '$modelDir/model_0.6B/conv_frontend.onnx',
              encoder: '$modelDir/model_0.6B/encoder.int8.onnx',
              decoder: '$modelDir/model_0.6B/decoder.int8.onnx',
              tokenizer: '$modelDir/tokenizer',
              maxNewTokens: 512,
            ),
            tokens: '',
            numThreads: 2,
            debug: false,
          ),
        );
    }
  }
}
