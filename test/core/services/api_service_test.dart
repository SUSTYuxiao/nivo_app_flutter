import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/core/services/api_service.dart';

void main() {
  group('ApiService', () {
    group('updateToken', () {
      test('sets Authorization header when token is provided', () {
        final service = ApiService();
        service.updateToken('my-token');
        expect(
          service.dio.options.headers['Authorization'],
          'Bearer my-token',
        );
      });

      test('removes Authorization header when token is null', () {
        final service = ApiService(token: 'initial');
        expect(service.dio.options.headers['Authorization'], 'Bearer initial');

        service.updateToken(null);
        expect(service.dio.options.headers.containsKey('Authorization'), false);
      });
    });

    group('getHistoryList', () {
      test('parses code==200 list response', () async {
        final service = ApiService();
        service.dio.httpClientAdapter = _MockAdapter(responseData: {
          'code': 200,
          'data': {
            'list': [
              {
                'id': '1',
                'title': '会议A',
                'userId': 'u1',
                'industry': '科技',
                'outputType': '深度纪要',
                'result': '结果',
                'input': '输入',
                'createTime': 1700000000000,
              },
            ],
            'total': 1,
            'current': 1,
            'pageSize': 20,
          },
        });

        final items = await service.getHistoryList(userId: 'u1');
        expect(items.length, 1);
        expect(items.first.id, '1');
        expect(items.first.title, '会议A');
      });

      test('returns empty list on non-200 code', () async {
        final service = ApiService();
        service.dio.httpClientAdapter = _MockAdapter(
          responseData: {'code': 500, 'message': 'error'},
        );

        final items = await service.getHistoryList(userId: 'u1');
        expect(items, isEmpty);
      });

      test('returns empty list when data is not a list', () async {
        final service = ApiService();
        service.dio.httpClientAdapter = _MockAdapter(
          responseData: {'code': 200, 'data': 'not-a-list'},
        );

        final items = await service.getHistoryList(userId: 'u1');
        expect(items, isEmpty);
      });
    });

    group('chatRun', () {
      test('returns data on success (code==200)', () async {
        final service = ApiService();
        service.dio.httpClientAdapter = _MockAdapter(
          responseData: {'code': 200, 'data': '# 会议纪要内容'},
        );

        final result = await service.chatRun(
          content: '转录文本',
          industry: '科技',
          outputType: '深度纪要',
        );
        expect(result, '# 会议纪要内容');
      });

      test('throws on non-200 code', () async {
        final service = ApiService();
        service.dio.httpClientAdapter = _MockAdapter(
          responseData: {'code': 500, 'message': 'server error'},
        );

        expect(
          () => service.chatRun(
            content: '转录文本',
            industry: '科技',
            outputType: '深度纪要',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}

class _MockAdapter implements HttpClientAdapter {
  final dynamic responseData;
  final int statusCode;
  _MockAdapter({required this.responseData, this.statusCode = 200}); // ignore: unused_element_parameter

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
