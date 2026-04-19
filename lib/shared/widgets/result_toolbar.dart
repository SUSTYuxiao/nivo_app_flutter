import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 结果工具栏：复制 / 分享 / 导出图片
class ResultToolbar extends StatefulWidget {
  final String content;
  final String title;
  final GlobalKey screenshotKey;

  const ResultToolbar({
    super.key,
    required this.content,
    this.title = '',
    required this.screenshotKey,
  });

  @override
  State<ResultToolbar> createState() => _ResultToolbarState();
}

class _ResultToolbarState extends State<ResultToolbar> {
  bool _isExporting = false;

  void _copy() {
    if (widget.content.isEmpty) {
      _showSnackBar('内容为空');
      return;
    }
    Clipboard.setData(ClipboardData(text: widget.content));
    _showSnackBar('已复制到剪贴板');
  }

  Future<void> _share() async {
    if (widget.content.isEmpty) {
      _showSnackBar('内容为空');
      return;
    }
    final text = widget.title.isNotEmpty
        ? '${widget.title}\n\n${widget.content}'
        : widget.content;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _exportImage() async {
    if (widget.content.isEmpty) {
      _showSnackBar('内容为空');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final boundary = widget.screenshotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/nivo_meeting_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (_) {
      _showSnackBar('导出失败');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
      ),
      child: Row(
        children: [
          _ToolButton(icon: Icons.copy_rounded, label: '复制', onTap: _copy),
          _ToolButton(icon: Icons.ios_share_rounded, label: '分享', onTap: _share),
          _ToolButton(
            icon: Icons.image_outlined,
            label: _isExporting ? '导出中...' : '导出图片',
            onTap: _isExporting ? null : _exportImage,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: const Color(0xFF73726E)),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF73726E))),
            ],
          ),
        ),
      ),
    );
  }
}
