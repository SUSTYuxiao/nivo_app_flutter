import 'package:flutter/foundation.dart';import '../../core/models/history_item.dart';
import '../../core/services/api_service.dart';

class HistoryProvider extends ChangeNotifier {
  ApiService? _apiService;
  String? _userId;

  final List<HistoryItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _timeRange;
  static const _pageSize = 20;

  List<HistoryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  String? get timeRange => _timeRange;

  void init({required ApiService apiService, required String userId}) {
    _apiService = apiService;
    _userId = userId;
  }

  void setTimeRange(String? range) {
    _timeRange = range;
    _currentPage = 1;
    _items.clear();
    _hasMore = true;
    notifyListeners();
    loadMore();
  }

  void clearTimeRange() {
    setTimeRange(null);
  }

  Future<void> refresh() async {
    _currentPage = 1;
    _items.clear();
    _hasMore = true;
    notifyListeners();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _apiService == null || _userId == null) {
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      int? startTime;
      int? endTime;
      if (_timeRange != null) {
        final now = DateTime.now();
        endTime = now.millisecondsSinceEpoch;
        if (_timeRange == 'today') {
          startTime = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        } else if (_timeRange == '7days') {
          startTime = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
        } else if (_timeRange == '30days') {
          startTime = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
        }
      }

      final newItems = await _apiService!.getHistoryList(
        userId: _userId!,
        current: _currentPage,
        pageSize: _pageSize,
        startTime: startTime,
        endTime: endTime,
      );
      _items.addAll(newItems);
      _hasMore = newItems.length >= _pageSize;
      _currentPage++;
    } catch (e) {
      // Silent error handling - UI checks if items is empty
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteItem(String id) async {
    if (_apiService == null || _userId == null) return;
    await _apiService!.deleteHistory(_userId!, id);
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> updateTitle(String id, String newTitle) async {
    if (_apiService == null || _userId == null) return;
    await _apiService!.updateHistoryTitle(_userId!, id, newTitle);
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final old = _items[index];
      _items[index] = HistoryItem(
        id: old.id,
        title: newTitle,
        userId: old.userId,
        email: old.email,
        industry: old.industry,
        outputType: old.outputType,
        result: old.result,
        input: old.input,
        createTime: old.createTime,
        updateTime: old.updateTime,
      );
      notifyListeners();
    }
  }
}
