import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../models/history_item.dart';

class ApiService {
  late final Dio _dio;

  ApiService({String? token}) {
    _dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  void updateToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  // --- 历史记录 ---

  Future<List<HistoryItem>> getHistoryList({
    required String userId,
    int current = 1,
    int pageSize = 20,
    int? startTime,
    int? endTime,
  }) async {
    final response = await _dio.get('/db/getHistoryList', queryParameters: {
      'userId': userId,
      'current': current,
      'pageSize': pageSize,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
    });
    final body = response.data;
    debugPrint('[ApiService] getHistoryList response: $body');
    if (body is Map && (body['code'] == 200 || body['success'] == true) && body['data'] is Map) {
      final data = body['data'] as Map;
      if (data['list'] is List) {
        return (data['list'] as List)
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<void> deleteHistory(String userId, String id) async {
    await _dio.post('/db/delHistory',
        data: FormData.fromMap({'userId': userId, 'id': id}));
  }

  Future<void> updateHistoryTitle(
      String userId, String id, String title) async {
    await _dio.post('/db/updateHistoryTitle',
        data: FormData.fromMap({'userId': userId, 'id': id, 'title': title}));
  }

  // --- 会议纪要生成 ---

  Future<String> chatRun({
    required String content,
    required String industry,
    required String outputType,
    required String appId,
    required String workflowId,
  }) async {
    final response = await _dio.post('/api/chat/run', data: {
      'app_id': appId,
      'workflow_id': workflowId,
      'parameters': {
        'Content': content,
        'Industry': industry,
        'Output_type': outputType,
        'app_id': appId,
        'audioNum': 0,
        'textNum': 0,
        'files': '',
      },
    });
    final body = response.data;
    if (body is Map && body['code'] == 200) {
      return body['data']?.toString() ?? '';
    }
    throw Exception('chatRun failed: ${body['message'] ?? 'unknown error'}');
  }

  // --- 音频数据发送 ---

  Future<void> sendAudioData(String sessionId, List<int> pcmData) async {
    await _dio.post(
      '/api/speech/audio',
      queryParameters: {'sessionId': sessionId},
      data: Stream.fromIterable([pcmData]),
      options: Options(contentType: 'application/octet-stream'),
    );
  }

  Future<void> sendStopSignal(String sessionId) async {
    await _dio.post('/api/speech/stop',
        queryParameters: {'sessionId': sessionId});
  }

  Dio get dio => _dio;
}
