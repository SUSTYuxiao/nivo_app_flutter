import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/api_service.dart';

class AfterMeetProvider extends ChangeNotifier {
  ApiService? _apiService;

  String _inputText = '';
  final List<String> _audioFilePaths = [];
  String? _result;
  bool _isGenerating = false;
  String? _errorMessage;

  String get inputText => _inputText;
  List<String> get audioFilePaths => List.unmodifiable(_audioFilePaths);
  String? get result => _result;
  bool get isGenerating => _isGenerating;
  String? get errorMessage => _errorMessage;

  void init({required ApiService apiService}) {
    _apiService = apiService;
  }

  void setInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  Future<void> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m4a', 'mp3', 'wav', 'aac', 'caf', 'flac', 'ogg'],
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
      final result = await _apiService!.chatRun(
        content: _inputText,
        industry: industry,
        outputType: template,
        appId: '',
        workflowId: '',
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
