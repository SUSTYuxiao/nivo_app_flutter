import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/models/history_item.dart';
import '../../shared/widgets/minutes_card.dart';
import 'history_provider.dart';

class HistoryDetailPage extends StatefulWidget {
  final HistoryItem item;
  const HistoryDetailPage({super.key, required this.item});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  final _screenshotKey = GlobalKey();

  String get _title =>
      widget.item.title.isNotEmpty ? widget.item.title : '未命名会议';

  String get _content {
    if (widget.item.result.isEmpty) return '';
    try {
      final parsed = jsonDecode(widget.item.result);
      if (parsed is Map) return (parsed['default'] as String?) ?? '';
    } catch (_) {}
    return widget.item.result;
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF91918E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF91918E)),
                    onSelected: (action) {
                      if (action == 'rename') _showRenameDialog(context);
                      if (action == 'ai_title') _generateTitle(context);
                      if (action == 'delete') _showDeleteDialog(context);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('修改标题')),
                      const PopupMenuItem(value: 'ai_title', child: Text('AI 生成标题')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除', style: TextStyle(color: AppColors.recording)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 纪要卡片
            Expanded(
              child: MinutesCard(
                title: _title,
                content: _content,
                date: DateTime.fromMillisecondsSinceEpoch(widget.item.createTime),
                industry: widget.item.industry,
                screenshotKey: _screenshotKey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateTitle(BuildContext context) async {
    _showSnackBar('正在生成标题...');
    final title = await context.read<HistoryProvider>().generateTitle(widget.item.id);
    if (!context.mounted) return;
    if (title != null && title.isNotEmpty) {
      _showSnackBar('标题已更新');
    } else {
      _showSnackBar('生成失败');
    }
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: widget.item.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改标题'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().updateTitle(widget.item.id, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复，确定要删除吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().deleteItem(widget.item.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.recording)),
          ),
        ],
      ),
    );
  }
}
