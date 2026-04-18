import 'dart:convert';

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
  }) async {
    final response = await _dio.post('/api/chat/run', data: {
      'app_id': '',
      'workflow_id': '',
      'parameters': {
        'Content': content,
        'Industry': industry,
        'Output_type': outputType,
        'app_id': '1',
        'audioNum': 0,
        'textNum': 0,
        'files': '',
      },
    });
    final body = response.data;
    if (body is Map && (body['code'] == 0 || body['code'] == 200 || body['success'] == true)) {
      final data = body['data'];
      if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map && parsed['data'] != null) {
            return parsed['data'].toString();
          }
          return data;
        } catch (_) {
          return data;
        }
      }
      return data?.toString() ?? '';
    }
    throw Exception('chatRun failed: ${body['message'] ?? body['msg'] ?? body['error'] ?? 'unknown error'}');
  }

  Dio get dio => _dio;

  // --- OSS ---

  Future<Map<String, dynamic>> getStsToken() async {
    // Web端不带auth调用此接口，用独立dio避免Bearer token干扰
    final plainDio = Dio(BaseOptions(baseUrl: apiBaseUrl));
    final response = await plainDio.get('/oss/getStsToken');
    final body = response.data;
    debugPrint('[ApiService] getStsToken response type: ${body.runtimeType}');
    if (body is Map) {
      // Format 1: {code: 200, data: {region, bucket, ...}}
      if ((body['code'] == 200 || body['success'] == true) && body['data'] is Map) {
        return body['data'] as Map<String, dynamic>;
      }
      // Format 2: direct {region, bucket, accessKeyId, ...}
      if (body.containsKey('accessKeyId') || body.containsKey('AccessKeyId')) {
        return Map<String, dynamic>.from(body);
      }
    }
    throw Exception('getStsToken failed: ${body is Map ? (body['message'] ?? body['msg'] ?? body) : body}');
  }

  // --- 云端转写 (说话人分离) ---

  Future<List<Map<String, dynamic>>> processAudioV2(String filePath) async {
    final response = await _dio.get(
      '/a2t/processV2',
      queryParameters: {'filePath': filePath},
      options: Options(
        receiveTimeout: const Duration(minutes: 10),
      ),
    );
    final body = response.data;
    if (body is Map &&
        (body['code'] == 200 || body['success'] == true) &&
        body['data'] is List) {
      return (body['data'] as List).cast<Map<String, dynamic>>();
    }
    // data 可能是嵌套 JSON 字符串
    if (body is Map && body['data'] is String) {
      try {
        final parsed = jsonDecode(body['data'] as String);
        if (parsed is List) {
          return parsed.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
    }
    throw Exception('processAudioV2 failed: ${body['message'] ?? body['msg'] ?? 'unknown'}');
  }

  // --- 云端转写时长 ---

  Future<Map<String, dynamic>> getRecordingDurationConfig(String userId) async {
    final response = await _dio.get('/api/recording-duration/config',
        queryParameters: {'userId': userId});
    final body = response.data;
    if (body is Map &&
        (body['code'] == 200 || body['success'] == true) &&
        body['data'] is Map) {
      return body['data'] as Map<String, dynamic>;
    }
    return {};
  }

  Future<void> reportRecordingDuration(String userId, int duration) async {
    await _dio.post('/api/recording-duration/report',
        queryParameters: {'userId': userId, 'duration': duration});
  }

  // --- 会员信息 ---

  Future<Map<String, dynamic>> getVipExpire(String userId) async {
    final response = await _dio.post('/api/pay/getVipExpire',
        data: FormData.fromMap({'userId': userId}));
    final body = response.data;
    if (body is Map && (body['code'] == 200 || body['success'] == true) && body['data'] is Map) {
      return body['data'] as Map<String, dynamic>;
    }
    return {};
  }
}
