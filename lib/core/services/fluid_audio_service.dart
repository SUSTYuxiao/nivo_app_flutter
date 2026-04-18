import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'transcription_service.dart';

/// Dart wrapper for FluidAudio iOS plugin.
/// Provides on-device ASR + speaker diarization via CoreML.
class FluidAudioService {
  static const _channel = MethodChannel('com.nivo/fluid_audio');

  /// Check if models are downloaded and ready.
  Future<bool> isModelReady() async {
    if (!Platform.isIOS) return false;
    try {
      final ready = await _channel.invokeMethod<bool>('isModelReady');
      return ready ?? false;
    } catch (e) {
      debugPrint('[FluidAudio] isModelReady error: $e');
      return false;
    }
  }

  /// Download ASR + diarization models. Call once, models are cached.
  Future<void> downloadModels({
    void Function(String status)? onStatus,
  }) async {
    if (!Platform.isIOS) throw UnsupportedError('FluidAudio is iOS only');
    onStatus?.call('正在下载模型...');
    try {
      await _channel.invokeMethod('downloadModels');
      onStatus?.call('模型就绪');
    } on PlatformException catch (e) {
      throw Exception('模型下载失败: ${e.message}');
    }
  }

  /// Transcribe audio file with speaker diarization.
  /// Returns sentences in the same format as cloud processV2.
  Future<List<TranscriptionSentence>> transcribeWithDiarization(
    String filePath,
  ) async {
    if (!Platform.isIOS) throw UnsupportedError('FluidAudio is iOS only');
    try {
      final result = await _channel.invokeMethod<List>(
        'transcribeWithDiarization',
        {'filePath': filePath},
      );
      if (result == null) return [];
      return result.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return TranscriptionSentence.fromJson(map);
      }).where((s) => s.text.isNotEmpty).toList();
    } on PlatformException catch (e) {
      throw Exception('本地转写失败: ${e.message}');
    }
  }
}
