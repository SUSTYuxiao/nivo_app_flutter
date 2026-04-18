import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/api_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/asr/ios_asr.dart';

class AfterMeetProvider extends ChangeNotifier {
  ApiService? _apiService;

  String _inputText = '';
  final List<String> _audioFilePaths = [];
  List<FileSystemEntity> _localRecordings = [];
  String? _result;
  bool _isGenerating = false;
  String? _errorMessage;

  String get inputText => _inputText;
  List<String> get audioFilePaths => List.unmodifiable(_audioFilePaths);
  List<FileSystemEntity> get localRecordings => List.unmodifiable(_localRecordings);
  String? get result => _result;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;

  void init({required ApiService apiService}) {
    _apiService = apiService;
  }

  Future<void> loadLocalRecordings() async {
    _localRecordings = await AudioService.listRecordings();
    notifyListeners();
  }

  void addLocalRecording(String path) {
    if (!_audioFilePaths.contains(path)) {
      _audioFilePaths.add(path);
      notifyListeners();
    }
  }

  Future<void> deleteLocalRecording(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _audioFilePaths.remove(path);
    _localRecordings.removeWhere((f) => f.path == path);
    notifyListeners();
  }

  void setInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  Future<void> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result != null) {
      for (final file in result.files) {
        if (file.path != null && !_audioFilePaths.contains(file.path)) {
          _audioFilePaths.add(file.path!);
        }
      }
      notifyListeners();
    }
  }

  void removeAudioFile(int index) {
    if (index >= 0 && index < _audioFilePaths.length) {
      _audioFilePaths.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> submit({
    required String industry,
    required String template,
  }) async {
    if (_apiService == null) return;
    if (_inputText.trim().isEmpty && _audioFilePaths.isEmpty) return;

    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Transcribe audio files if any
      final transcripts = <String>[];
      if (_inputText.trim().isNotEmpty) {
        transcripts.add(_inputText.trim());
      }

      for (final path in _audioFilePaths) {
        try {
          if (Platform.isIOS) {
            final text = await IosAsr.transcribeFile(path);
            if (text.isNotEmpty) transcripts.add(text);
          }
          // TODO: Android offline transcription via sherpa_onnx
        } catch (e) {
          debugPrint('Transcribe failed for $path: $e');
        }
      }

      if (transcripts.isEmpty) {
        _errorMessage = '没有可用的文本内容';
        return;
      }

      // Step 2: chatRun with combined text
      final content = transcripts.join('\n\n');
      final result = await _apiService!.chatRun(
        content: content,
        industry: industry,
        outputType: template,
      );
      _result = result;
    } catch (e) {
      _errorMessage = '生成失败: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void reset() {
    _inputText = '';
    _audioFilePaths.clear();
    _result = null;
    _isGenerating = false;
    _errorMessage = null;
    notifyListeners();
  }
}
