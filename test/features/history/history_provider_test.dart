import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/features/history/history_provider.dart';

void main() {
  group('HistoryProvider', () {
    test('initial state defaults to 7days filter', () {
      final provider = HistoryProvider();
      expect(provider.items, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.timeRange, '7days');
      expect(provider.currentPage, 1);
    });

    test('setTimeRange updates filter and resets page', () {
      final provider = HistoryProvider();
      provider.setTimeRange('today');
      expect(provider.timeRange, 'today');
      expect(provider.currentPage, 1);
    });

    test('loadMore when not initialized is a no-op', () async {
      final provider = HistoryProvider();
      await provider.loadMore();
      expect(provider.items, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.currentPage, 1);
    });

    test('loadMore when isLoading is true is a no-op (no double-fetch)',
        () async {
      final provider = HistoryProvider();
      await Future.wait([provider.loadMore(), provider.loadMore()]);
      expect(provider.items, isEmpty);
      expect(provider.isLoading, false);
    });
  });
}
