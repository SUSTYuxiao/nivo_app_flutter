import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/core/constants.dart';
import 'package:nivo_app/core/services/asr/asr_backend.dart';
import 'package:nivo_app/core/services/asr/asr_router.dart';
import 'package:nivo_app/core/services/asr/cloud_asr.dart';
import 'package:nivo_app/core/services/asr/sherpa_asr.dart';

/// Fake that records calls so we can verify delegation.
class FakeCloudAsr extends CloudAsr {
  bool startStreamCalled = false;
  bool sendAudioCalled = false;
  bool stopStreamCalled = false;

  FakeCloudAsr() : super(dio: null);

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) async {
    startStreamCalled = true;
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) async {
    sendAudioCalled = true;
  }

  @override
  Future<void> stopStream() async {
    stopStreamCalled = true;
  }
}

class FakeSherpaAsr extends SherpaAsr {
  bool startStreamCalled = false;
  bool sendAudioCalled = false;
  bool stopStreamCalled = false;

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) async {
    startStreamCalled = true;
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) async {
    sendAudioCalled = true;
  }

  @override
  Future<void> stopStream() async {
    stopStreamCalled = true;
  }
}

void _noop(String text, bool isFinal) {}
void _noopError(String error) {}

void main() {
  group('AsrRouter', () {
    late FakeCloudAsr fakeCloud;
    late FakeSherpaAsr fakeSherpa;

    setUp(() {
      fakeCloud = FakeCloudAsr();
      fakeSherpa = FakeSherpaAsr();
    });

    test('auto mode with nivo transcription delegates to CloudAsr', () async {
      final router = AsrRouter(
        cloud: fakeCloud,
        sherpa: fakeSherpa,
        mode: AsrMode.auto,
        useNivoTranscription: true,
      );

      await router.startStream(
        sessionId: 's1',
        onTranscription: _noop,
        onError: _noopError,
      );

      expect(fakeCloud.startStreamCalled, true);
      expect(fakeSherpa.startStreamCalled, false);
    });

    test('local mode delegates startStream to SherpaAsr', () async {
      final router = AsrRouter(
        cloud: fakeCloud,
        sherpa: fakeSherpa,
        mode: AsrMode.local,
      );

      await router.startStream(
        sessionId: 's1',
        onTranscription: _noop,
        onError: _noopError,
      );

      expect(fakeSherpa.startStreamCalled, true);
      expect(fakeCloud.startStreamCalled, false);
    });

    test('sendAudio when _active is null returns without throwing', () async {
      final router = AsrRouter(
        cloud: fakeCloud,
        sherpa: fakeSherpa,
      );

      // _active is null because startStream was never called
      await router.sendAudio(Uint8List(0));

      expect(fakeCloud.sendAudioCalled, false);
      expect(fakeSherpa.sendAudioCalled, false);
    });

    test('stopStream sets _active to null so subsequent sendAudio is no-op',
        () async {
      final router = AsrRouter(
        cloud: fakeCloud,
        sherpa: fakeSherpa,
        mode: AsrMode.auto,
      );

      await router.startStream(
        sessionId: 's1',
        onTranscription: _noop,
        onError: _noopError,
      );
      await router.stopStream();

      // Reset flag to check that sendAudio does NOT reach the backend
      fakeCloud.sendAudioCalled = false;
      await router.sendAudio(Uint8List(10));
      expect(fakeCloud.sendAudioCalled, false);
    });
  });
}
