import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../constants.dart';
import 'asr_backend.dart';

class CloudAsr implements AsrBackend {
  final Dio _dio;
  StreamSubscription<String>? _sseSub;
  String? _sessionId;

  CloudAsr({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl));

  @override
  Future<void> startStream({
    required String sessionId,
    required TranscriptionCallback onTranscription,
    required void Function(String error) onError,
  }) async {
    _sessionId = sessionId;

    final response = await _dio.get<ResponseBody>(
      '/api/speech/start',
      queryParameters: {'sessionId': sessionId},
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data!.stream.cast<List<int>>();
    _sseSub = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          if (data.isNotEmpty) {
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final text = json['text'] as String? ?? '';
              final isFinal = json['isFinal'] as bool? ?? false;
              if (text.isNotEmpty) {
                onTranscription(text, isFinal);
              }
            } catch (_) {
              onTranscription(data, false);
            }
          }
        }
      },
      onError: (Object e) => onError(e.toString()),
    );
  }

  @override
  Future<void> sendAudio(Uint8List pcmData) async {
    if (_sessionId == null) return;
    await _dio.post(
      '/api/speech/audio',
      queryParameters: {'sessionId': _sessionId},
      data: Stream.fromIterable([pcmData]),
      options: Options(contentType: 'application/octet-stream'),
    );
  }

  @override
  Future<void> stopStream() async {
    await _sseSub?.cancel();
    _sseSub = null;
    if (_sessionId != null) {
      await _dio.post('/api/speech/stop',
          queryParameters: {'sessionId': _sessionId});
      _sessionId = null;
    }
  }
}
