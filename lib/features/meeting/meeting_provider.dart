import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/transcription.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/asr/asr_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/duration_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/services/live_activity_service.dart';
import '../history/history_provider.dart';
import '../settings/settings_provider.dart';

enum MeetingPhase { idle, recording, result }

class MeetingProvider extends ChangeNotifier {
  AudioService? _audioService;
  AsrRouter? _asrRouter;
  ApiService? _apiService;
  DurationService? _durationService;
  TranscriptionService? _transcriptionService;
  SettingsProvider? _settingsProvider;
  HistoryProvider? _historyProvider;
  LiveActivityService? _liveActivityService;

  MeetingPhase _phase = MeetingPhase.idle;
  final List<Transcription> _transcriptions = [];
  String? _meetingResult;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _isPaused = false;
  bool _globalCapture = false;
  String? _sessionId;
  String? _lastRecordingPath;
  bool _isGenerating = false;
  String? _errorMessage;
  String? _userId;
  String _generatingStatus = '';
  /// Saved value to restore after meeting ends
  bool? _savedUseNivoTranscription;
  /// 后台超时自动暂停（2小时）
  DateTime? _backgroundEnteredAt;
  static const _backgroundTimeout = Duration(hours: 2);
  /// ASR 重建中标志，防止与 endMeeting 竞态
  Future<void>? _rebuildFuture;

  MeetingPhase get phase => _phase;
  List<Transcription> get transcriptions => List.unmodifiable(_transcriptions);
  String? get meetingResult => _meetingResult;
  Duration get elapsed => _elapsed;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  String? get lastRecordingPath => _lastRecordingPath;
  bool get isPaused => _isPaused;
  bool get globalCapture => _globalCapture;
  String get generatingStatus => _generatingStatus;

  /// App 进入后台时调用
  void onAppPaused() {
    if (_phase != MeetingPhase.recording || _isPaused) return;
    _backgroundEnteredAt = DateTime.now();
    debugPrint('[MeetingProvider] onAppPaused at $_backgroundEnteredAt');
  }

  /// App 回到前台时调用
  void onAppResumed() {
    if (_backgroundEnteredAt == null) return;
    final bg = DateTime.now().difference(_backgroundEnteredAt!);
    _backgroundEnteredAt = null;
    debugPrint('[MeetingProvider] onAppResumed after ${bg.inSeconds}s');
    if (bg >= _backgroundTimeout && _phase == MeetingPhase.recording && !_isPaused) {
      pauseTimer();
      return;
    }
    // 前台恢复：重建 ASR 管线，确保转写正常
    if (_phase == MeetingPhase.recording && !_isPaused) {
      _rebuildFuture = _rebuildAsrStream();
    }
  }

  /// 重建 ASR 流（stop + start），用于前台恢复后确保管线健康
  Future<void> _rebuildAsrStream() async {
    if (_asrRouter == null || _sessionId == null) return;
    debugPrint('[MeetingProvider] rebuilding ASR stream');
    try {
      await _asrRouter!.stopStream();
      // 检查：rebuild 期间如果会议已结束/暂停，不再 start
      if (_phase != MeetingPhase.recording || _isPaused) return;
      // 用新 sessionId，因为 stopStream 会结束服务端旧 session
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _asrRouter!.startStream(
        sessionId: _sessionId!,
        onTranscription: (text, isFinal) {
          addTranscription(text, isFinal: isFinal);
        },
        onError: (error) {
          debugPrint('[MeetingProvider] ASR error after rebuild: $error');
          _errorMessage = error;
          notifyListeners();
        },
      );
      debugPrint('[MeetingProvider] ASR stream rebuilt with session $_sessionId');
    } catch (e) {
      debugPrint('[MeetingProvider] ASR rebuild failed: $e');
    } finally {
      _rebuildFuture = null;
    }
  }

  void init({
    required AudioService audioService,
    required AsrRouter asrRouter,
    required ApiService apiService,
    DurationService? durationService,
    TranscriptionService? transcriptionService,
    SettingsProvider? settingsProvider,
    HistoryProvider? historyProvider,
    LiveActivityService? liveActivityService,
  }) {
    _audioService = audioService;
    _asrRouter = asrRouter;
    _apiService = apiService;
    _durationService = durationService;
    _transcriptionService = transcriptionService;
    _settingsProvider = settingsProvider;
    _historyProvider = historyProvider;
    _liveActivityService = liveActivityService;
  }

  void setUserId(String userId) {
    _userId = userId;
  }

  void addTranscription(String text, {bool isFinal = false}) {
    if (_transcriptions.isNotEmpty && !_transcriptions.last.isFinal) {
      _transcriptions[_transcriptions.length - 1] = Transcription(
        text: text,
        timestamp: DateTime.now(),
        isFinal: isFinal,
        elapsed: _elapsed,
      );
    } else {
      _transcriptions.add(Transcription(
        text: text,
        timestamp: DateTime.now(),
        isFinal: isFinal,
        elapsed: _elapsed,
      ));
    }
    notifyListeners();
  }

  Future<void> startMeeting() async {
    if (_audioService == null || _asrRouter == null) return;
    if (_phase == MeetingPhase.recording) return; // guard against double start

    // Save current useNivoTranscription to restore after meeting
    _savedUseNivoTranscription = _asrRouter!.useNivoTranscription;

    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _phase = MeetingPhase.recording;
    _transcriptions.clear();
    _meetingResult = null;
    _errorMessage = null;
    _elapsed = Duration.zero;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });

    // 启动灵动岛
    _liveActivityService?.start(meetingId: _sessionId!, elapsedSeconds: 0);

    // Global capture: fetch duration config and start segment timing
    if (_globalCapture && _durationService != null && _userId != null) {
      await _durationService!.fetchConfig(_userId!);
      if (_durationService!.isLimitReached) {
        _errorMessage = '云端转写时长已用完，请升级套餐';
        _timer?.cancel();
        _timer = null;
        _phase = MeetingPhase.idle;
        _restoreUseNivoTranscription();
        _liveActivityService?.end();
        notifyListeners();
        return;
      }
      _durationService!.startSegment(onLimitReached: _onDurationLimitReached);
    }

    await _asrRouter!.startStream(
      sessionId: _sessionId!,
      onTranscription: (text, isFinal) {
        addTranscription(text, isFinal: isFinal);
      },
      onError: (error) {
        _errorMessage = error;
        notifyListeners();
      },
    );

    await _audioService!.startRecording(
      onAudioData: (pcmData) {
        _asrRouter!.sendAudio(pcmData);
      },
      echoCancel: false,
      autoGain: false,
    );
  }

  Future<void> pauseTimer() async {
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
    if (_globalCapture && _durationService != null) {
      await _durationService!.stopSegment();
    }
    await _audioService?.pauseRecording();
    _liveActivityService?.update(isPaused: true, elapsedSeconds: _elapsed.inSeconds);
    notifyListeners();
  }

  Future<void> resumeTimer() async {
    if (!_isPaused) return;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    if (_globalCapture && _durationService != null) {
      _durationService!.startSegment(onLimitReached: _onDurationLimitReached);
    }
    await _audioService?.resumeRecording();
    _liveActivityService?.update(isPaused: false, elapsedSeconds: _elapsed.inSeconds);
    notifyListeners();
  }

  void _onDurationLimitReached() {
    _errorMessage = '云端转写时长已用完，会议已自动停止';
    _durationService?.stopSegment();
    _audioService?.stopRecording();
    _asrRouter?.stopStream();
    _timer?.cancel();
    _timer = null;
    _phase = MeetingPhase.idle;
    _restoreUseNivoTranscription();
    _liveActivityService?.end();
    notifyListeners();
  }

  void setGlobalCapture(bool enabled) {
    _globalCapture = enabled;
    _asrRouter?.useNivoTranscription = enabled;
    notifyListeners();
  }

  Future<void> endMeeting({
    required String industry,
    required String template,
  }) async {
    if (_isGenerating) return; // guard against double call
    // 等待 ASR 重建完成，防止竞态泄漏
    if (_rebuildFuture != null) {
      await _rebuildFuture;
    }
    _backgroundEnteredAt = null;
    _timer?.cancel();
    _timer = null;

    if (_globalCapture && _durationService != null) {
      await _durationService!.endMeeting();
    }

    _lastRecordingPath = await _audioService?.stopRecording();
    await _asrRouter?.stopStream();
    _liveActivityService?.end();

    _isGenerating = true;
    _generatingStatus = '正在转写...';
    notifyListeners();

    try {
      String content;

      // Try cloud transcription if we have a recording and the service
      if (_lastRecordingPath != null && _transcriptionService != null) {
        try {
          _generatingStatus = '上传录音...';
          notifyListeners();

          final sentences = await _transcriptionService!.transcribeAudio(
            _lastRecordingPath!,
            onProgress: (progress, status) {
              _generatingStatus = status;
              notifyListeners();
            },
          );
          content = TranscriptionService.formatAsMarkdown(sentences);
          debugPrint('[MeetingProvider] cloud transcription: ${sentences.length} sentences, ${content.length} chars');
        } catch (e) {
          debugPrint('[MeetingProvider] cloud transcription failed, falling back to realtime: $e');
          content = _transcriptions.map((t) => t.text).join('\n');
          debugPrint('[MeetingProvider] fallback realtime text: ${content.length} chars');
        }
      } else {
        content = _transcriptions.map((t) => t.text).join('\n');
      }

      _generatingStatus = '生成纪要中...';
      notifyListeners();

      final useStreaming = _settingsProvider?.useStreaming ?? true;

      if (useStreaming) {
        _meetingResult = '';
        // 不在这里切 phase，等首字到达再切，避免白屏
        notifyListeners();
        final sb = StringBuffer();
        var lastNotify = DateTime.now();
        bool firstChunk = true;
        await for (final chunk in _apiService!.chatRunStream(
          content: content,
          industry: industry,
          outputType: template,
        )) {
          sb.write(chunk);
          if (firstChunk && sb.toString().trim().isNotEmpty) {
            // 首字到达，切换到结果页，跳过节流
            _meetingResult = sb.toString();
            _phase = MeetingPhase.result;
            firstChunk = false;
            lastNotify = DateTime.now();
            notifyListeners();
          } else {
            final now = DateTime.now();
            if (now.difference(lastNotify).inMilliseconds >= 100) {
              _meetingResult = sb.toString();
              lastNotify = now;
              notifyListeners();
            }
          }
        }
        _meetingResult = sb.toString();
        if (firstChunk) {
          // SSE 返回了空内容，仍需切换 phase
          _phase = MeetingPhase.result;
          _errorMessage = '服务端未返回任何内容';
        }
        notifyListeners();
      } else {
        final result = await _apiService!.chatRun(
          content: content,
          industry: industry,
          outputType: template,
        );
        _meetingResult = result;
        _phase = MeetingPhase.result;
      }

      // 自动保存到历史
      await _saveToHistory(content: content, industry: industry, outputType: template);
    } catch (e) {
      _errorMessage = '纪要生成失败: $e';
      _phase = MeetingPhase.result;
    } finally {
      _isGenerating = false;
      _generatingStatus = '';
      _restoreUseNivoTranscription();
      notifyListeners();
    }
  }

  Future<void> reset() async {
    _backgroundEnteredAt = null;
    _timer?.cancel();
    _timer = null;
    if (_globalCapture && _durationService != null) {
      await _durationService!.endMeeting();
    }
    await _audioService?.stopRecording();
    await _asrRouter?.stopStream();
    _liveActivityService?.end();
    _phase = MeetingPhase.idle;
    _transcriptions.clear();
    _meetingResult = null;
    _elapsed = Duration.zero;
    _sessionId = null;
    _lastRecordingPath = null;
    _isPaused = false;
    _globalCapture = false;
    _isGenerating = false;
    _errorMessage = null;
    _restoreUseNivoTranscription();
    notifyListeners();
  }

  void _restoreUseNivoTranscription() {
    if (_savedUseNivoTranscription != null) {
      _asrRouter?.useNivoTranscription = _savedUseNivoTranscription!;
      _savedUseNivoTranscription = null;
    }
  }

  Future<void> _saveToHistory({
    required String content,
    required String industry,
    required String outputType,
  }) async {
    if (_meetingResult == null || _meetingResult!.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final historyId = await _apiService!.addHistory(
        userId: user.id,
        email: user.email ?? '',
        result: _meetingResult!,
        input: jsonEncode({'Content': content, 'Industry': industry, 'Output_type': outputType}),
      );
      await _historyProvider?.refresh();
      // 异步生成 AI 标题（不阻塞主流程）
      if (historyId != null && historyId.isNotEmpty) {
        _apiService!.generateTitle(historyId).then((title) {
          if (title != null) _historyProvider?.refresh();
        }).catchError((e) {
          debugPrint('[MeetingProvider] generateTitle failed: $e');
        });
      }
    } catch (e) {
      debugPrint('[MeetingProvider] save history failed: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _durationService?.dispose();
    super.dispose();
  }
}
