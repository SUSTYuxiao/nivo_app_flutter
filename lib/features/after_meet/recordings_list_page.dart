import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants.dart';
import '../../core/services/audio_service.dart';

class RecordingsListPage extends StatefulWidget {
  final void Function(String path)? onSelect;
  const RecordingsListPage({super.key, this.onSelect});

  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  List<FileSystemEntity> _recordings = [];
  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;
  bool _isPlaying = false;

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
                  const Text('历史录音',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _recordings.isEmpty
                  ? Center(
                      child: Text('暂无录音',
                          style: TextStyle(color: Colors.grey.shade400)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recordings.length,
                      itemBuilder: (context, index) {
                        final file = _recordings[index];
                        final name = file.path.split('/').last;
                        final stat = file.statSync();
                        final date = DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
                        final sizeMb = (stat.size / 1024 / 1024).toStringAsFixed(1);
                        final isCurrentPlaying = _playingPath == file.path;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
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
                              if (widget.onSelect != null)
                                GestureDetector(
                                  onTap: () {
                                    widget.onSelect!(file.path);
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withAlpha(25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('选择',
                                        style: TextStyle(fontSize: 12, color: AppColors.accent)),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _deleteRecording(file.path, name),
                                child: const Icon(Icons.delete_outline, size: 18, color: AppColors.neutral),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
