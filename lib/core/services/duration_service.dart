import 'dart:async';
import 'api_service.dart';

class DurationService {
  final ApiService _apiService;

  int _globalUsage = 0;
  int _globalLimit = 0;
  int _meetingDuration = 0;
  int _segmentDuration = 0;
  Timer? _ticker;
  Timer? _reportTimer;
  String? _userId;

  int get globalUsage => _globalUsage;
  int get globalLimit => _globalLimit;
  int get meetingDuration => _meetingDuration;
  bool get isLimitReached => _globalLimit > 0 && _globalUsage >= _globalLimit;

  DurationService({required ApiService apiService}) : _apiService = apiService;

  Future<void> fetchConfig(String userId) async {
    _userId = userId;
    final data = await _apiService.getRecordingDurationConfig(userId);
    _globalUsage = data['usage'] as int? ?? 0;
    _globalLimit = data['limit'] as int? ?? 0;
  }

  void startSegment() {
    _segmentDuration = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _segmentDuration++;
      _meetingDuration++;
      _globalUsage++;
    });

    // 60s periodic report
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _reportCurrentSegment();
    });
  }

  Future<void> stopSegment() async {
    _ticker?.cancel();
    _ticker = null;
    _reportTimer?.cancel();
    _reportTimer = null;
    if (_segmentDuration > 0 && _userId != null) {
      await _apiService.reportRecordingDuration(_userId!, _segmentDuration);
    }
    _segmentDuration = 0;
  }

  Future<void> endMeeting() async {
    await stopSegment();
    _meetingDuration = 0;
  }

  Future<void> _reportCurrentSegment() async {
    if (_segmentDuration > 0 && _userId != null) {
      final toReport = _segmentDuration;
      _segmentDuration = 0;
      await _apiService.reportRecordingDuration(_userId!, toReport);
    }
  }

  void dispose() {
    _ticker?.cancel();
    _reportTimer?.cancel();
  }
}
