import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/models/transcription.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/asr/asr_router.dart';
import '../../core/services/asr/ios_asr.dart';
import '../../core/services/api_service.dart';

enum MeetingPhase { idle, recording, result }

class MeetingProvider extends ChangeNotifier {
  AudioService? _audioService;
  AsrRouter? _asrRouter;
  ApiService? _apiService;

  MeetingPhase _phase = MeetingPhase.idle;
  final List<Transcription> _transcriptions = [];
  String? _meetingResult;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _isPaused = false;
  bool _voiceIsolation = false;
  String? _sessionId;
  String? _lastRecordingPath;
  bool _isGenerating = false;
  String? _errorMessage;

  MeetingPhase get phase => _phase;
  List<Transcription> get transcriptions => List.unmodifiable(_transcriptions);
  String? get meetingResult => _meetingResult;
  Duration get elapsed => _elapsed;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;
  String? get lastRecordingPath => _lastRecordingPath;
  bool get isPaused => _isPaused;
  bool get voiceIsolation => _voiceIsolation;

  void init({
    required AudioService audioService,
    required AsrRouter asrRouter,
    required ApiService apiService,
  }) {
    _audioService = audioService;
    _asrRouter = asrRouter;
    _apiService = apiService;
  }

  void addTranscription(String text, {bool isFinal = false}) {
    if (_transcriptions.isNotEmpty && !_transcriptions.last.isFinal) {
      // Last entry is partial: update in-place (partial→partial or partial→final)
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

    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _phase = MeetingPhase.recording;
    _transcriptions.clear();
    _meetingResult = null;
    _errorMessage = null;
    _elapsed = Duration.zero;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });

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
    );
  }

  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isPaused = true;
    notifyListeners();
  }

  void resumeTimer() {
    if (!_isPaused) return;
    _isPaused = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> setVoiceIsolation(bool enabled) async {
    _voiceIsolation = enabled;
    if (Platform.isIOS) {
      await IosAsr.setVoiceIsolation(enabled);
    }
    notifyListeners();
  }

  Future<void> endMeeting({
    required String industry,
    required String template,
  }) async {
    _timer?.cancel();
    _timer = null;

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
      notifyListeners();
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _phase = MeetingPhase.idle;
    _transcriptions.clear();
    _meetingResult = null;
    _elapsed = Duration.zero;
    _sessionId = null;
    _lastRecordingPath = null;
    _isPaused = false;
    _isGenerating = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
