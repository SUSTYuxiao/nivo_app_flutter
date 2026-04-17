import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  AsrMode _asrMode = AsrMode.cloud;
  String _cloudApiBaseUrl = apiBaseUrl;
  String _asrModelId = '';

  AsrMode get asrMode => _asrMode;
  String get cloudApiBaseUrl => _cloudApiBaseUrl;
  String get asrModelId => _asrModelId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _asrMode = AsrMode.values.byName(
      _prefs.getString('asr_mode') ?? AsrMode.cloud.name,
    );
    _cloudApiBaseUrl = _prefs.getString('cloud_api_base_url') ?? apiBaseUrl;
    _asrModelId = _prefs.getString('asr_model_id') ?? '';
  }

  Future<void> setAsrMode(AsrMode mode) async {
    _asrMode = mode;
    await _prefs.setString('asr_mode', mode.name);
    notifyListeners();
  }

  Future<void> setCloudApiBaseUrl(String url) async {
    _cloudApiBaseUrl = url;
    await _prefs.setString('cloud_api_base_url', url);
    notifyListeners();
  }

  Future<void> setAsrModelId(String id) async {
    _asrModelId = id;
    await _prefs.setString('asr_model_id', id);
    notifyListeners();
  }
}
