import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/services/asr/asr_models.dart';
import '../../core/services/asr/asr_router.dart';
import '../../core/services/asr/sherpa_asr.dart';
import '../../core/services/fluid_audio_service.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  SherpaAsr? _sherpaAsr;
  AsrRouter? _asrRouter;
  FluidAudioService? _fluidAudioService;

  AsrMode _asrMode = AsrMode.auto;
  String _cloudApiBaseUrl = apiBaseUrl;
  String _asrModelId = '';
  bool _useNivoTranscription = false;
  bool _devMode = false;
  bool _useStreaming = true;
  TranscribeMode _transcribeMode = TranscribeMode.cloud;
  bool _fluidAudioModelReady = false;
  bool _isDownloadingFluidAudioModel = false;
  String _fluidAudioDownloadStatus = '';

  double _modelDownloadProgress = 0.0;
  bool _isDownloadingModel = false;
  String? _downloadingModelId;

  // Track which models are downloaded
  final Map<String, bool> _modelDownloadStatus = {};

  AsrMode get asrMode => _asrMode;
  String get cloudApiBaseUrl => _cloudApiBaseUrl;
  String get asrModelId => _asrModelId;
  bool get useNivoTranscription => _useNivoTranscription;
  bool get devMode => _devMode;
  bool get useStreaming => _useStreaming;
  TranscribeMode get transcribeMode => _transcribeMode;
  bool get fluidAudioModelReady => _fluidAudioModelReady;
  bool get isDownloadingFluidAudioModel => _isDownloadingFluidAudioModel;
  String get fluidAudioDownloadStatus => _fluidAudioDownloadStatus;
  double get modelDownloadProgress => _modelDownloadProgress;
  bool get isDownloadingModel => _isDownloadingModel;
  String? get downloadingModelId => _downloadingModelId;

  void setSherpaAsr(SherpaAsr asr) {
    _sherpaAsr = asr;
  }

  void setAsrRouter(AsrRouter router) {
    _asrRouter = router;
  }

  void setFluidAudioService(FluidAudioService service) {
    _fluidAudioService = service;
  }

  Future<void> refreshFluidAudioModelStatus() async {
    if (_fluidAudioService == null) return;
    _fluidAudioModelReady = await _fluidAudioService!.isModelReady();
    notifyListeners();
  }

  Future<void> downloadFluidAudioModels() async {
    if (_fluidAudioService == null || _isDownloadingFluidAudioModel) return;
    _isDownloadingFluidAudioModel = true;
    _fluidAudioDownloadStatus = '准备下载...';
    notifyListeners();

    try {
      await _fluidAudioService!.downloadModels(
        onStatus: (status) {
          _fluidAudioDownloadStatus = status;
          notifyListeners();
        },
      );
      _fluidAudioModelReady = true;
    } catch (e) {
      _fluidAudioDownloadStatus = '下载失败: $e';
    } finally {
      _isDownloadingFluidAudioModel = false;
      notifyListeners();
    }
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
    _devMode = _prefs.getBool('dev_mode') ?? false;
    _useStreaming = _prefs.getBool('use_streaming') ?? true;
    _transcribeMode = TranscribeMode.values.byName(
      _prefs.getString('transcribe_mode') ?? TranscribeMode.local.name,
    );
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
    _asrRouter?.mode = mode;
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
    _asrRouter?.useNivoTranscription = value;
    await _prefs.setBool('use_nivo_transcription', value);
    notifyListeners();
  }

  Future<void> setDevMode(bool value) async {
    _devMode = value;
    await _prefs.setBool('dev_mode', value);
    notifyListeners();
  }

  Future<void> setUseStreaming(bool value) async {
    _useStreaming = value;
    await _prefs.setBool('use_streaming', value);
    notifyListeners();
  }

  Future<void> setTranscribeMode(TranscribeMode mode) async {
    _transcribeMode = mode;
    await _prefs.setString('transcribe_mode', mode.name);
    notifyListeners();
  }
}
