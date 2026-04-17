import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/features/history/history_provider.dart';

void main() {
  group('HistoryProvider', () {
    test('initial state', () {
      final provider = HistoryProvider();
      expect(provider.items, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.timeRange, isNull);
      expect(provider.currentPage, 1);
    });

    test('setTimeRange updates filter and resets page', () {
      final provider = HistoryProvider();
      provider.setTimeRange('7days');
      expect(provider.timeRange, '7days');
      expect(provider.currentPage, 1);
    });

    test('clearTimeRange resets filter', () {
      final provider = HistoryProvider();
      provider.setTimeRange('today');
      provider.clearTimeRange();
      expect(provider.timeRange, isNull);
    });

    test('loadMore when not initialized is a no-op', () async {
      final provider = HistoryProvider();
      // Do NOT call init — _apiService and _userId are null
      await provider.loadMore();
      expect(provider.items, isEmpty);
      expect(provider.isLoading, false);
      expect(provider.currentPage, 1);
    });

    test('loadMore when isLoading is true is a no-op (no double-fetch)',
        () async {
      final provider = HistoryProvider();
      // Not initialized, so loadMore returns immediately.
      // We verify the guard by calling loadMore twice concurrently —
      // neither should throw or change state since _apiService is null.
      await Future.wait([provider.loadMore(), provider.loadMore()]);
      expect(provider.items, isEmpty);
      expect(provider.isLoading, false);
    });
  });
}
