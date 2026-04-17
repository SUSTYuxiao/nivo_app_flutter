import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/core/models/history_item.dart';

void main() {
  group('HistoryItem.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': '123',
        'title': '测试会议',
        'userId': 'user1',
        'email': 'test@test.com',
        'industry': '科技',
        'outputType': '深度纪要',
        'result': '# 会议纪要',
        'input': '转录文本',
        'createTime': 1713400000000,
        'updateTime': 1713400001000,
      };
      final item = HistoryItem.fromJson(json);
      expect(item.id, '123');
      expect(item.title, '测试会议');
      expect(item.industry, '科技');
      expect(item.createTime, 1713400000000);
    });

    test('handles missing optional fields', () {
      final json = {
        'id': '456',
        'userId': 'user2',
        'createTime': 1713400000000,
      };
      final item = HistoryItem.fromJson(json);
      expect(item.title, '');
      expect(item.email, isNull);
      expect(item.updateTime, isNull);
    });
  });
}
