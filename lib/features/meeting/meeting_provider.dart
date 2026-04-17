import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/transcription.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/asr/asr_router.dart';
import '../../core/services/api_service.dart';

enum MeetingPhase { prepare, recording, result }

class MeetingProvider extends ChangeNotifier {
  AudioService? _audioService;
  AsrRouter? _asrRouter;
  ApiService? _apiService;

  MeetingPhase _phase = MeetingPhase.prepare;
  final List<Transcription> _transcriptions = [];
  String? _meetingResult;
  String _industry = '企业服务';
  String _template = '深度纪要';
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _sessionId;
  bool _isGenerating = false;
  String? _errorMessage;

  MeetingPhase get phase => _phase;
  List<Transcription> get transcriptions => List.unmodifiable(_transcriptions);
  String? get meetingResult => _meetingResult;
  String get industry => _industry;
  String get template => _template;
  Duration get elapsed => _elapsed;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;

  void init({
    required AudioService audioService,
    required AsrRouter asrRouter,
    required ApiService apiService,
  }) {
    _audioService = audioService;
    _asrRouter = asrRouter;
    _apiService = apiService;
  }

  void setIndustry(String value) {
    _industry = value;
    notifyListeners();
  }

  void setTemplate(String value) {
    _template = value;
    notifyListeners();
  }

  void addTranscription(String text, {bool isFinal = false}) {
    _transcriptions.add(Transcription(
      text: text,
      timestamp: DateTime.now(),
      isFinal: isFinal,
    ));
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

  Future<void> endMeeting() async {
    _timer?.cancel();
    _timer = null;

    await _audioService?.stopRecording();
    await _asrRouter?.stopStream();

    _isGenerating = true;
    notifyListeners();

    try {
      final fullTranscript = _transcriptions.map((t) => t.text).join('\n');
      final result = await _apiService!.chatRun(
        content: fullTranscript,
        industry: _industry,
        outputType: _template,
        appId: '',
        workflowId: '',
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
    _phase = MeetingPhase.prepare;
    _transcriptions.clear();
    _meetingResult = null;
    _elapsed = Duration.zero;
    _sessionId = null;
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
