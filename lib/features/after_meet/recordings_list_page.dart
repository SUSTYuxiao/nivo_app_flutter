import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants.dart';
import '../../core/services/audio_service.dart';

class RecordingsListPage extends StatefulWidget {
  const RecordingsListPage({super.key});

  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  List<FileSystemEntity> _recordings = [];
  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;
  bool _isPlaying = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playingPath = null;
            _isPlaying = false;
          }
        });
      }
    });
  }

  Future<void> _loadRecordings() async {
    final files = await AudioService.listRecordings();
    if (mounted) setState(() => _recordings = files);
  }

  Future<void> _togglePlay(String path) async {
    if (_playingPath == path && _isPlaying) {
      await _player.pause();
    } else if (_playingPath == path) {
      await _player.play();
    } else {
      await _player.setFilePath(path);
      _playingPath = path;
      await _player.play();
    }
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  Future<void> _importFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            _selected.add(file.path!);
          }
        }
      });
    }
  }

  void _showVoiceMemoGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('从语音备忘录导入',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _guideStep('1', '打开 iPhone 自带的「语音备忘录」App'),
            const SizedBox(height: 12),
            _guideStep('2', '长按要导入的录音，点击「分享」'),
            const SizedBox(height: 12),
            _guideStep('3', '选择「存储到"文件"」，保存到任意位置'),
            const SizedBox(height: 12),
            _guideStep('4', '回到本页面，点击「导入文件」选择刚保存的文件'),
            const SizedBox(height: 24),
            Text(
              '语音备忘录不支持直接访问，需要先分享到「文件」App',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(25),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF37352F))),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteRecording(String path, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除录音'),
        content: Text('确定删除 $name 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (_playingPath == path) {
        await _player.stop();
        _playingPath = null;
      }
      _selected.remove(path);
      final file = File(path);
      if (await file.exists()) await file.delete();
      await _loadRecordings();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Imported files that are not in local recordings
    final importedPaths = _selected
        .where((p) => !_recordings.any((r) => r.path == p))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('选择录音',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: _importFromFiles,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open, size: 14, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('导入文件',
                              style: TextStyle(fontSize: 12, color: AppColors.accent)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showVoiceMemoGuide(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_none, size: 14, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('语音备忘录',
                              style: TextStyle(fontSize: 12, color: AppColors.accent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _recordings.isEmpty && importedPaths.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('暂无录音',
                              style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(height: 16),
                          CupertinoButton(
                            onPressed: _importFromFiles,
                            child: const Text('从文件导入',
                                style: TextStyle(fontSize: 14, color: AppColors.accent)),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // Imported external files
                        if (importedPaths.isNotEmpty) ...[
                          Text('导入的文件',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          ...importedPaths.map((path) {
                            final name = path.split('/').last;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.accent.withAlpha(50)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                                  GestureDetector(
                                    onTap: () => setState(() => _selected.remove(path)),
                                    child: const Icon(Icons.close, size: 16, color: AppColors.neutral),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        // Local recordings
                        if (_recordings.isNotEmpty) ...[
                          Text('本地录音',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                        ],
                        ..._recordings.map((file) {
                          final name = file.path.split('/').last;
                          final stat = file.statSync();
                          final date = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
                          final sizeMb = (stat.size / 1024 / 1024).toStringAsFixed(1);
                          final isCurrentPlaying = _playingPath == file.path;
                          final isSelected = _selected.contains(file.path);

                          return GestureDetector(
                            onTap: () => _toggleSelect(file.path),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent.withAlpha(15) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? Border.all(color: AppColors.accent.withAlpha(50))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _togglePlay(file.path),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withAlpha(25),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        isCurrentPlaying && _isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: AppColors.accent,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text('$date · ${sizeMb}MB',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 22,
                                    color: isSelected ? AppColors.accent : AppColors.neutral,
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _deleteRecording(file.path, name),
                                    child: const Icon(Icons.delete_outline, size: 18, color: AppColors.neutral),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
            // Bottom confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: CupertinoButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  color: AppColors.accent,
                  disabledColor: AppColors.accent.withAlpha(80),
                  borderRadius: BorderRadius.circular(24),
                  padding: EdgeInsets.zero,
                  child: Text(
                    _selected.isEmpty ? '请选择录音' : '确认选择 (${_selected.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
