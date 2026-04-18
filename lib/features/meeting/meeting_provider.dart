import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/transcription.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/asr/asr_router.dart';
import '../../core/services/api_service.dart';
import '../../core/services/duration_service.dart';

enum MeetingPhase { idle, recording, result }

class MeetingProvider extends ChangeNotifier {
  AudioService? _audioService;
  AsrRouter? _asrRouter;
  ApiService? _apiService;
  DurationService? _durationService;

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
  /// Saved value to restore after meeting ends
  bool? _savedUseNivoTranscription;

  MeetingPhase get phase => _phase;
  List<Transcription> get transcriptions => List.unmodifiable(_transcriptions);
  String? get meetingResult => _meetingResult;
  Duration get elapsed => _elapsed;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  String? get lastRecordingPath => _lastRecordingPath;
  bool get isPaused => _isPaused;
  bool get globalCapture => _globalCapture;

  void init({
    required AudioService audioService,
    required AsrRouter asrRouter,
    required ApiService apiService,
    DurationService? durationService,
  }) {
    _audioService = audioService;
    _asrRouter = asrRouter;
    _apiService = apiService;
    _durationService = durationService;
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
      );
    } else {
      _transcriptions.add(Transcription(
        text: text,
        timestamp: DateTime.now(),
        isFinal: isFinal,
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

    // Global capture: fetch duration config and start segment timing
    if (_globalCapture && _durationService != null && _userId != null) {
      await _durationService!.fetchConfig(_userId!);
      if (_durationService!.isLimitReached) {
        _errorMessage = '云端转写时长已用完，请升级套餐';
        _timer?.cancel();
        _timer = null;
        _phase = MeetingPhase.idle;
        _restoreUseNivoTranscription();
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
    notifyListeners();
  }

  void resumeTimer() {
    if (!_isPaused) return;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    if (_globalCapture && _durationService != null) {
      _durationService!.startSegment(onLimitReached: _onDurationLimitReached);
    }
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
    _timer?.cancel();
    _timer = null;

    if (_globalCapture && _durationService != null) {
      await _durationService!.endMeeting();
    }

    _lastRecordingPath = await _audioService?.stopRecording();
    await _asrRouter?.stopStream();

    _isGenerating = true;
    notifyListeners();

    try {
      final fullTranscript = _transcriptions.map((t) => t.text).join('\n');
      final result = await _apiService!.chatRun(
        content: fullTranscript,
        industry: industry,
        outputType: template,
      );
      _meetingResult = result;
      _phase = MeetingPhase.result;
    } catch (e) {
      _errorMessage = '纪要生成失败: $e';
    } finally {
      _isGenerating = false;
      _restoreUseNivoTranscription();
      notifyListeners();
    }
  }

  Future<void> reset() async {
    _timer?.cancel();
    _timer = null;
    if (_globalCapture && _durationService != null) {
      await _durationService!.endMeeting();
    }
    await _audioService?.stopRecording();
    await _asrRouter?.stopStream();
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

  @override
  void dispose() {
    _timer?.cancel();
    _durationService?.dispose();
    super.dispose();
  }
}
