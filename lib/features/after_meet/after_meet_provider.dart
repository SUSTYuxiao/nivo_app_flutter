import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/services/fluid_audio_service.dart';

class AfterMeetProvider extends ChangeNotifier {
  ApiService? _apiService;
  TranscriptionService? _transcriptionService;
  FluidAudioService? _fluidAudioService;

  String _inputText = '';
  final List<String> _audioFilePaths = [];
  String? _result;
  bool _isGenerating = false;
  String? _errorMessage;
  double _progress = 0.0;
  String _progressStatus = '';

  String get inputText => _inputText;
  List<String> get audioFilePaths => List.unmodifiable(_audioFilePaths);
  String? get result => _result;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  String get progressStatus => _progressStatus;

  void init({
    required ApiService apiService,
    TranscriptionService? transcriptionService,
    FluidAudioService? fluidAudioService,
  }) {
    _apiService = apiService;
    _transcriptionService = transcriptionService;
    _fluidAudioService = fluidAudioService;
  }

  void addLocalRecording(String path) {
    if (!_audioFilePaths.contains(path)) {
      _audioFilePaths.add(path);
      notifyListeners();
    }
  }

  void removeAudioFile(int index) {
    if (index >= 0 && index < _audioFilePaths.length) {
      _audioFilePaths.removeAt(index);
      notifyListeners();
    }
  }

  void setInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  Future<void> submit({
    required String industry,
    required String template,
    required TranscribeMode transcribeMode,
  }) async {
    if (_apiService == null) return;
    if (_inputText.trim().isEmpty && _audioFilePaths.isEmpty) return;

    _isGenerating = true;
    _errorMessage = null;
    _progress = 0.0;
    _progressStatus = '';
    notifyListeners();

    try {
      final transcripts = <String>[];
      if (_inputText.trim().isNotEmpty) {
        transcripts.add(_inputText.trim());
      }

      final useCloud = transcribeMode == TranscribeMode.cloud &&
          _transcriptionService != null;

      for (var i = 0; i < _audioFilePaths.length; i++) {
        final path = _audioFilePaths[i];
        final fileLabel = '(${i + 1}/${_audioFilePaths.length})';
        try {
          if (useCloud) {
            _progressStatus = '上传中 $fileLabel';
            notifyListeners();

            final sentences = await _transcriptionService!.transcribeAudio(
              path,
              onProgress: (p, status) {
                _progress = (i + p) / _audioFilePaths.length;
                _progressStatus = '$status $fileLabel';
                notifyListeners();
              },
            );
            final md = TranscriptionService.formatAsMarkdown(sentences);
            if (md.isNotEmpty) transcripts.add(md);
          } else if (Platform.isIOS && _fluidAudioService != null) {
            // Local mode: FluidAudio (ASR + speaker diarization)
            final isReady = await _fluidAudioService!.isModelReady();
            if (!isReady) {
              _progressStatus = '下载模型中 $fileLabel';
              notifyListeners();
              await _fluidAudioService!.downloadModels(
                onStatus: (status) {
                  _progressStatus = '$status $fileLabel';
                  notifyListeners();
                },
              );
            }
            _progressStatus = '本地转写中 $fileLabel';
            notifyListeners();
            final sentences = await _fluidAudioService!.transcribeWithDiarization(path);
            debugPrint('[AfterMeet] FluidAudio transcription for $path: ${sentences.length} sentences');
            for (final s in sentences) {
              debugPrint('[AfterMeet]   [${s.beginTime}ms] ${s.speakerName}: ${s.text}');
            }
            final md = TranscriptionService.formatAsMarkdown(sentences);
            if (md.isNotEmpty) transcripts.add(md);
          }
          // Android without cloud: no local transcription yet
        } catch (e) {
          debugPrint('Transcribe failed for $path: $e');
        }
      }

      if (transcripts.isEmpty) {
        _errorMessage = '没有可用的文本内容';
        return;
      }

      _progressStatus = '生成纪要中...';
      _progress = 1.0;
      notifyListeners();

      final content = transcripts.join('\n\n');
      final result = await _apiService!.chatRun(
        content: content,
        industry: industry,
        outputType: template,
      );
      _result = result;
    } catch (e) {
      _errorMessage = '生成失败: $e';
    } finally {
      _isGenerating = false;
      _progress = 0.0;
      _progressStatus = '';
      notifyListeners();
    }
  }

  void reset() {
    _inputText = '';
    _audioFilePaths.clear();
    _result = null;
    _isGenerating = false;
    _errorMessage = null;
    notifyListeners();
  }
}
