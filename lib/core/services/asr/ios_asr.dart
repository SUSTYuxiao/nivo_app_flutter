import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'asr_backend.dart';

/// iOS-native ASR using SFSpeechRecognizer via platform channel.
/// Receives PCM data from record package via sendAudio(), feeds it to
/// native SFSpeechRecognizer through MethodChannel.
class IosAsr implements AsrBackend {
  static const _methodChannel = MethodChannel('com.nivo/native_asr');
  static const _eventChannel = EventChannel('com.nivo/native_asr/events');

  TranscriptionCallback? _onTranscription;
  StreamSubscription? _eventSubscription;
  bool _isStreaming = false;

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
    bool onDevice = false,
  }) async {
    if (!Platform.isIOS) {
      onError('NativeAsr only available on iOS');
      return;
    }

    _onTranscription = onTranscription;

    // Cancel previous listener if any
    await _eventSubscription?.cancel();

    // Listen for transcription events from native
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final text = event['text'] as String? ?? '';
          final isFinal = event['isFinal'] as bool? ?? false;
          if (text.isNotEmpty) {
            _onTranscription?.call(text, isFinal);
          }
        }
      },
      onError: (Object error) {
        onError(error.toString());
      },
    );

    try {
      await _methodChannel.invokeMethod('start', {'onDevice': onDevice});
      _isStreaming = true;
    } on PlatformException catch (e) {
      onError(e.message ?? '语音识别启动失败');
    }
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) async {
    if (!_isStreaming) return;
    try {
      await _methodChannel.invokeMethod('feedAudio', pcmData);
    } catch (_) {}
  }

  @override
  Future<void> stopStream() async {
    if (_isStreaming) {
      try {
        await _methodChannel.invokeMethod('stop');
      } catch (_) {}
      _isStreaming = false;
    }
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _onTranscription = null;
  }

  /// Transcribe an audio file offline using SFSpeechRecognizer.
  /// Returns the transcribed text.
  static Future<String> transcribeFile(String filePath, {bool onDevice = false}) async {
    final result = await _methodChannel.invokeMethod<String>('transcribeFile', {
      'filePath': filePath,
      'onDevice': onDevice,
    });
    return result ?? '';
  }

  /// Set microphone voice isolation mode.
  /// true = Voice Isolation (filter noise including speakers)
  /// false = Wide Spectrum (capture all sounds)
  static Future<void> setVoiceIsolation(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setVoiceIsolation', enabled);
    } catch (_) {}
  }
}
