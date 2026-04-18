import 'dart:convert';

import 'package:dio/dio.dart';
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

  // --- 会员信息 ---

  Future<Map<String, dynamic>> getVipExpire(String userId) async {
    final response = await _dio.post('/api/pay/getVipExpire', data: {'userId': userId});
    final body = response.data;
    if (body is Map && (body['code'] == 200 || body['success'] == true) && body['data'] is Map) {
      return body['data'] as Map<String, dynamic>;
    }
    return {};
  }
}
