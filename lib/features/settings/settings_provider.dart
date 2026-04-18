import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/services/asr/asr_models.dart';
import '../../core/services/asr/sherpa_asr.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  SherpaAsr? _sherpaAsr;

  AsrMode _asrMode = AsrMode.auto;
  String _cloudApiBaseUrl = apiBaseUrl;
  String _asrModelId = '';
  bool _useNivoTranscription = false;

  double _modelDownloadProgress = 0.0;
  bool _isDownloadingModel = false;
  String? _downloadingModelId;

  // Track which models are downloaded
  final Map<String, bool> _modelDownloadStatus = {};

  AsrMode get asrMode => _asrMode;
  String get cloudApiBaseUrl => _cloudApiBaseUrl;
  String get asrModelId => _asrModelId;
  bool get useNivoTranscription => _useNivoTranscription;
  double get modelDownloadProgress => _modelDownloadProgress;
  bool get isDownloadingModel => _isDownloadingModel;
  String? get downloadingModelId => _downloadingModelId;

  void setSherpaAsr(SherpaAsr asr) {
    _sherpaAsr = asr;
  }

  bool isModelDownloaded(String modelId) =>
      _modelDownloadStatus[modelId] ?? false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _asrMode = AsrMode.values.byName(
      _prefs.getString('asr_mode') ?? AsrMode.auto.name,
    );
    _cloudApiBaseUrl = _prefs.getString('cloud_api_base_url') ?? apiBaseUrl;
    _asrModelId = _prefs.getString('asr_model_id') ?? '';
    _useNivoTranscription = _prefs.getBool('use_nivo_transcription') ?? false;
  }

  /// Refresh download status for all known models.
  Future<void> refreshModelStatus() async {
    if (_sherpaAsr == null) return;
    for (final model in kAsrModels) {
      _modelDownloadStatus[model.id] =
          await _sherpaAsr!.isModelDownloaded(model.id);
    }
    notifyListeners();
  }

  Future<void> startModelDownload(String modelId) async {
    if (_sherpaAsr == null || _isDownloadingModel) return;
    _isDownloadingModel = true;
    _downloadingModelId = modelId;
    _modelDownloadProgress = 0.0;
    notifyListeners();

    try {
      await for (final progress in _sherpaAsr!.downloadModel(modelId)) {
        _modelDownloadProgress = progress;
        notifyListeners();
      }
      _modelDownloadStatus[modelId] = true;
    } catch (e) {
      // Download failed — leave status as not downloaded
    } finally {
      _isDownloadingModel = false;
      _downloadingModelId = null;
      notifyListeners();
    }
  }

  Future<void> deleteModel(String modelId) async {
    if (_sherpaAsr == null) return;
    await _sherpaAsr!.deleteModel(modelId);
    _modelDownloadStatus[modelId] = false;
    notifyListeners();
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

  Future<void> setUseNivoTranscription(bool value) async {
    _useNivoTranscription = value;
    await _prefs.setBool('use_nivo_transcription', value);
    notifyListeners();
  }
}
