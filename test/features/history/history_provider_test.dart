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
  });
}
