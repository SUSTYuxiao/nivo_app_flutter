import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/services/fluid_audio_service.dart';
import '../history/history_provider.dart';
import '../settings/settings_provider.dart';

class AfterMeetProvider extends ChangeNotifier {
  ApiService? _apiService;
  TranscriptionService? _transcriptionService;
  FluidAudioService? _fluidAudioService;
  SettingsProvider? _settingsProvider;
  HistoryProvider? _historyProvider;

  String _inputText = '';
  final List<String> _audioFilePaths = [];
  String? _result;
  String? _errorMessage;
  double _progress = 0.0;
  String _progressStatus = '';

  // 新增：阶段 + 错误收集
  ProcessingStage _stage = ProcessingStage.idle;
  int _currentFile = 0;
  int _totalFiles = 0;
  final List<String> _fileErrors = [];
  String? _warningMessage;
  Timer? _fakeProgressTimer;

  String get inputText => _inputText;
  List<String> get audioFilePaths => List.unmodifiable(_audioFilePaths);
  String? get result => _result;
  bool get isGenerating => _stage != ProcessingStage.idle && _stage != ProcessingStage.error;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  String get progressStatus => _progressStatus;
  ProcessingStage get stage => _stage;
  String? get warningMessage => _warningMessage;

  void init({
    required ApiService apiService,
    TranscriptionService? transcriptionService,
    FluidAudioService? fluidAudioService,
    SettingsProvider? settingsProvider,
    HistoryProvider? historyProvider,
  }) {
    _apiService = apiService;
    _transcriptionService = transcriptionService;
    _fluidAudioService = fluidAudioService;
    _settingsProvider = settingsProvider;
    _historyProvider = historyProvider;
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

  /// 启动假进度 Timer（渐近曲线，永远不到 upperBound）
  void _startFakeProgress({
    required double from,
    required double upperBound,
    double tau = 120.0,
  }) {
    _stopFakeProgress();
    final startTime = DateTime.now();
    final range = upperBound - from;
    _fakeProgressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final elapsed = DateTime.now().difference(startTime).inSeconds.toDouble();
      _progress = from + range * (1 - math.exp(-elapsed / tau));
      notifyListeners();
    });
  }

  void _stopFakeProgress() {
    _fakeProgressTimer?.cancel();
    _fakeProgressTimer = null;
  }

  void _setStage(ProcessingStage stage, {String? status, double? progress}) {
    _stage = stage;
    if (status != null) _progressStatus = status;
    if (progress != null) _progress = progress;
    notifyListeners();
  }

  String get _fileLabel =>
      _totalFiles > 1 ? '(${_currentFile + 1}/$_totalFiles)' : '';

  Future<void> submit({
    required String industry,
    required String template,
    required TranscribeMode transcribeMode,
  }) async {
    if (_apiService == null) return;
    if (_inputText.trim().isEmpty && _audioFilePaths.isEmpty) return;

    _errorMessage = null;
    _warningMessage = null;
    _progress = 0.0;
    _progressStatus = '';
    _fileErrors.clear();
    _totalFiles = _audioFilePaths.length;
    _currentFile = 0;
    _setStage(ProcessingStage.preparing,
        status: '准备中...', progress: 0.0);

    try {
      final transcripts = <String>[];
      if (_inputText.trim().isNotEmpty) {
        transcripts.add(_inputText.trim());
      }

      final useCloud = transcribeMode == TranscribeMode.cloud &&
          _transcriptionService != null;

      for (var i = 0; i < _audioFilePaths.length; i++) {
        final path = _audioFilePaths[i];
        _currentFile = i;
        try {
          if (useCloud) {
            // 阶段：准备上传
            _setStage(ProcessingStage.preparing,
                status: '准备上传... $_fileLabel', progress: 0.0);

            final sentences = await _transcriptionService!.transcribeAudio(
              path,
              onProgress: (prog, status) {
                if (prog <= 0) {
                  // getStsToken 阶段，保持 preparing
                  _setStage(ProcessingStage.preparing,
                      status: '准备上传... $_fileLabel');
                } else if (prog < 0.9) {
                  // 上传阶段，有真实进度
                  _setStage(ProcessingStage.uploading,
                      status: '上传中 $_fileLabel',
                      progress: (i + prog) / _totalFiles);
                } else if (prog < 1.0) {
                  // 服务端转写阶段，启动假进度
                  if (_stage != ProcessingStage.cloudTranscribing) {
                    final baseProgress = (i + 0.9) / _totalFiles;
                    _setStage(ProcessingStage.cloudTranscribing,
                        status: '服务器处理中... $_fileLabel',
                        progress: baseProgress);
                    _startFakeProgress(
                      from: baseProgress,
                      upperBound: (i + 0.98) / _totalFiles,
                      tau: 120.0,
                    );
                  }
                } else {
                  // 完成
                  _stopFakeProgress();
                }
              },
            );
            _stopFakeProgress();
            final md = TranscriptionService.formatAsMarkdown(sentences);
            if (md.isNotEmpty) transcripts.add(md);
          } else if (Platform.isIOS && _fluidAudioService != null) {
            // Local mode: FluidAudio (ASR + speaker diarization)
            final isReady = await _fluidAudioService!.isModelReady();
            if (!isReady) {
              _setStage(ProcessingStage.downloadingModel,
                  status: '下载语音模型（仅首次）... $_fileLabel',
                  progress: 0.0);
              await _fluidAudioService!.downloadModels(
                onStatus: (status) {
                  _progressStatus = '$status $_fileLabel';
                  notifyListeners();
                },
              );
            }

            // 本地转写：启动假进度
            _setStage(ProcessingStage.localTranscribing,
                status: '本地转写中... $_fileLabel', progress: 0.0);

            // 基于文件大小估算 tau（粗略：16kHz mono PCM ≈ 32KB/s）
            final fileSize = await File(path).length();
            final estimatedAudioSec = fileSize / 32000;
            final tau = (estimatedAudioSec * 0.5).clamp(10.0, 300.0);
            _startFakeProgress(from: 0.0, upperBound: 0.95, tau: tau);

            final sentences = await _fluidAudioService!.transcribeWithDiarization(path);
            _stopFakeProgress();

            debugPrint('[AfterMeet] FluidAudio transcription for $path: ${sentences.length} sentences');
            final md = TranscriptionService.formatAsMarkdown(sentences);
            if (md.isNotEmpty) transcripts.add(md);
          }
          // Android without cloud: no local transcription yet
        } catch (e) {
          debugPrint('Transcribe failed for $path: $e');
          _stopFakeProgress();
          _fileErrors.add(p.basename(path));
        }
      }

      if (transcripts.isEmpty) {
        if (_fileErrors.isNotEmpty) {
          _errorMessage = '所有文件转写失败：${_fileErrors.join(", ")}';
        } else {
          _errorMessage = '没有可用的文本内容';
        }
        _setStage(ProcessingStage.error);
        return;
      }

      // 部分失败警告
      if (_fileErrors.isNotEmpty) {
        _warningMessage = '${_fileErrors.join(", ")} 转写失败，已跳过';
      }

      final content = transcripts.join('\n\n');
      final useStreaming = _settingsProvider?.useStreaming ?? true;

      // 生成纪要阶段：不设 progress=1.0，用 indeterminate
      if (useStreaming) _result = '';
      _setStage(ProcessingStage.generating,
          status: '生成纪要中...', progress: 0.0);

      if (useStreaming) {
        final sb = StringBuffer();
        var lastNotify = DateTime.now();
        await for (final chunk in _apiService!.chatRunStream(
          content: content,
          industry: industry,
          outputType: template,
        )) {
          sb.write(chunk);
          final now = DateTime.now();
          if (now.difference(lastNotify).inMilliseconds >= 100) {
            _result = sb.toString();
            lastNotify = now;
            notifyListeners();
          }
        }
        _result = sb.toString();
        notifyListeners();
      } else {
        final result = await _apiService!.chatRun(
          content: content,
          industry: industry,
          outputType: template,
        );
        _result = result;
      }

      // 自动保存到历史
      await _saveToHistory(content: content, industry: industry, outputType: template);
    } catch (e) {
      _errorMessage = '生成失败: $e';
      _setStage(ProcessingStage.error);
    } finally {
      _stopFakeProgress();
      _progress = 0.0;
      _progressStatus = '';
      _stage = ProcessingStage.idle;
      notifyListeners();
    }
  }

  void reset() {
    _inputText = '';
    _audioFilePaths.clear();
    _result = null;
    _errorMessage = null;
    _warningMessage = null;
    _fileErrors.clear();
    _stage = ProcessingStage.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopFakeProgress();
    super.dispose();
  }

  Future<void> _saveToHistory({
    required String content,
    required String industry,
    required String outputType,
  }) async {
    if (_result == null || _result!.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await _apiService!.addHistory(
        userId: user.id,
        email: user.email ?? '',
        result: _result!,
        input: jsonEncode({'Content': content, 'Industry': industry, 'Output_type': outputType}),
      );
      await _historyProvider?.refresh();
    } catch (e) {
      debugPrint('[AfterMeetProvider] save history failed: $e');
    }
  }
}
