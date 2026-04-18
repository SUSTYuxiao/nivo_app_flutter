import 'package:flutter/foundation.dart';
import 'api_service.dart';

class VipProvider extends ChangeNotifier {
  ApiService? _apiService;
  String? _productType;
  int? _expireTime; // unix seconds
  bool _isFree = true;
  String? _productName;
  bool _devModeSimulateFree = false;

  bool get isVip => !_devModeSimulateFree && !_isFree && !isExpired;

  bool get isExpired =>
      _expireTime != null &&
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > _expireTime!;

  String get productType => _productType ?? '';
  String get productName => _productName ?? '';
  int? get expireTime => _expireTime;
  bool get isFree => _isFree;
  bool get devModeSimulateFree => _devModeSimulateFree;

  void init(ApiService apiService) {
    _apiService = apiService;
  }

  Future<void> fetchVipStatus(String userId) async {
    if (_apiService == null) return;
    try {
      final data = await _apiService!.getVipExpire(userId);
      _productType = data['productTypeCur'] as String? ?? '';
      _expireTime = data['expireTimeCur'] as int?;
      _isFree = data['isFree'] as bool? ?? true;
      _productName = data['productName'] as String?;
    } catch (_) {
      _productType = '';
      _expireTime = null;
      _isFree = true;
      _productName = null;
    }
    notifyListeners();
  }

  void setDevModeSimulateFree(bool v) {
    _devModeSimulateFree = v;
    notifyListeners();
  }
}
