import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/features/meeting/meeting_provider.dart';

void main() {
  group('MeetingProvider', () {
    test('initial phase is idle', () {
      final provider = MeetingProvider();
      expect(provider.phase, MeetingPhase.idle);
      expect(provider.transcriptions, isEmpty);
      expect(provider.meetingResult, isNull);
    });

    test('reset returns to idle phase', () {
      final provider = MeetingProvider();
      provider.reset();
      expect(provider.phase, MeetingPhase.idle);
      expect(provider.transcriptions, isEmpty);
      expect(provider.meetingResult, isNull);
      expect(provider.elapsed, Duration.zero);
    });

    test('addTranscription appends to list', () {
      final provider = MeetingProvider();
      provider.addTranscription('你好', isFinal: true);
      expect(provider.transcriptions.length, 1);
      expect(provider.transcriptions.first.text, '你好');
      expect(provider.transcriptions.first.isFinal, true);
    });

    test('startMeeting when not initialized returns early, phase stays idle',
        () async {
      final provider = MeetingProvider();
      await provider.startMeeting();
      expect(provider.phase, MeetingPhase.idle);
      expect(provider.transcriptions, isEmpty);
    });

    test('addTranscription multiple times grows the list', () {
      final provider = MeetingProvider();
      provider.addTranscription('第一句', isFinal: true);
      provider.addTranscription('第二句', isFinal: true);
      provider.addTranscription('第三句', isFinal: true);
      expect(provider.transcriptions.length, 3);
      expect(provider.transcriptions[0].text, '第一句');
      expect(provider.transcriptions[1].text, '第二句');
      expect(provider.transcriptions[2].text, '第三句');
      expect(provider.transcriptions[2].isFinal, true);
    });

    test('partial transcription updates last entry in-place', () {
      final provider = MeetingProvider();
      provider.addTranscription('你');
      provider.addTranscription('你好');
      provider.addTranscription('你好世界', isFinal: true);
      expect(provider.transcriptions.length, 1);
      expect(provider.transcriptions[0].text, '你好世界');
      expect(provider.transcriptions[0].isFinal, true);
    });

    test('reset clears everything including elapsed', () {
      final provider = MeetingProvider();
      provider.addTranscription('测试');

      provider.reset();

      expect(provider.phase, MeetingPhase.idle);
      expect(provider.transcriptions, isEmpty);
      expect(provider.meetingResult, isNull);
      expect(provider.elapsed, Duration.zero);
      expect(provider.isGenerating, false);
      expect(provider.errorMessage, isNull);
    });
  });
}
