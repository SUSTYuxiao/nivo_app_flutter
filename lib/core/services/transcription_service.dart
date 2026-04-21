import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'oss_service.dart';

class TranscriptionSentence {
  final int beginTime;
  final int endTime;
  final String text;
  final int speakerId;
  final String speakerName;

  TranscriptionSentence({
    required this.beginTime,
    required this.endTime,
    required this.text,
    required this.speakerId,
    required this.speakerName,
  });

  factory TranscriptionSentence.fromJson(Map<String, dynamic> json) {
    return TranscriptionSentence(
      beginTime: (json['beginTime'] ?? json['begin_time'] as num?)?.toInt() ?? 0,
      endTime: (json['endTime'] ?? json['end_time'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      speakerId: (json['speakerId'] ?? json['speaker_id'] as num?)?.toInt() ?? 0,
      speakerName: json['speakerName'] as String? ?? '发言人${(json['speakerId'] ?? json['speaker_id'] ?? 0)}',
    );
  }
}

class TranscriptionService {
  final ApiService _apiService;
  final OssService _ossService;

  TranscriptionService({
    required ApiService apiService,
    required OssService ossService,
  })  : _apiService = apiService,
        _ossService = ossService;

  /// Upload audio to OSS then call processV2 for speaker-diarized transcription.
  Future<List<TranscriptionSentence>> transcribeAudio(
    String localPath, {
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.0, '准备上传...');

    final ossKey = await _ossService.uploadAudio(
      localPath,
      onProgress: (p) {
        if (p >= 1.0) {
          onProgress?.call(0.9, '等待服务器确认...');
        } else {
          onProgress?.call(p * 0.9, '上传中');
        }
      },
    );

    onProgress?.call(0.9, '转写中');

    final rawList = await _apiService.processAudioV2(ossKey);
    final sentences = rawList
        .map((e) => TranscriptionSentence.fromJson(e))
        .where((s) => s.text.isNotEmpty)
        .toList();

    debugPrint('[TranscriptionService] cloud transcription done: ${sentences.length} sentences');
    for (final s in sentences) {
      debugPrint('[TranscriptionService]   [${_formatTime(s.beginTime)}] ${s.speakerName}: ${s.text}');
    }

    onProgress?.call(1.0, '完成');
    return sentences;
  }

  /// Format sentences as speaker-labeled markdown (matches meetAg web output).
  static String formatAsMarkdown(List<TranscriptionSentence> sentences) {
    return sentences.map((s) {
      final time = _formatTime(s.beginTime);
      return '**${s.speakerName} - $time**\n\n${s.text}';
    }).join('\n\n');
  }

  static String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '$minutes分${seconds.toString().padLeft(2, '0')}秒';
    }
    return '$seconds秒';
  }
}
