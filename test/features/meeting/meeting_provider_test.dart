import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/features/meeting/meeting_provider.dart';

void main() {
  group('MeetingProvider', () {
    test('initial phase is prepare', () {
      final provider = MeetingProvider();
      expect(provider.phase, MeetingPhase.prepare);
      expect(provider.transcriptions, isEmpty);
      expect(provider.meetingResult, isNull);
    });

    test('setIndustry updates industry', () {
      final provider = MeetingProvider();
      provider.setIndustry('金融');
      expect(provider.industry, '金融');
    });

    test('setTemplate updates template', () {
      final provider = MeetingProvider();
      provider.setTemplate('深度纪要');
      expect(provider.template, '深度纪要');
    });

    test('reset returns to prepare phase', () {
      final provider = MeetingProvider();
      provider.reset();
      expect(provider.phase, MeetingPhase.prepare);
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

    test('startMeeting when not initialized returns early, phase stays prepare',
        () async {
      final provider = MeetingProvider();
      // Do NOT call init — services are null
      await provider.startMeeting();
      expect(provider.phase, MeetingPhase.prepare);
      expect(provider.transcriptions, isEmpty);
    });

    test('addTranscription multiple times grows the list', () {
      final provider = MeetingProvider();
      provider.addTranscription('第一句');
      provider.addTranscription('第二句');
      provider.addTranscription('第三句', isFinal: true);
      expect(provider.transcriptions.length, 3);
      expect(provider.transcriptions[0].text, '第一句');
      expect(provider.transcriptions[1].text, '第二句');
      expect(provider.transcriptions[2].text, '第三句');
      expect(provider.transcriptions[2].isFinal, true);
    });

    test('reset clears everything including elapsed', () {
      final provider = MeetingProvider();
      // Add some state
      provider.addTranscription('测试');
      provider.setIndustry('金融');
      provider.setTemplate('对话式纪要');

      provider.reset();

      expect(provider.phase, MeetingPhase.prepare);
      expect(provider.transcriptions, isEmpty);
      expect(provider.meetingResult, isNull);
      expect(provider.elapsed, Duration.zero);
      expect(provider.isGenerating, false);
      expect(provider.errorMessage, isNull);
    });
  });
}
