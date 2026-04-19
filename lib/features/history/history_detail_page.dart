import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/models/history_item.dart';
import '../../shared/widgets/result_toolbar.dart';
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

  String get _dateStr => DateFormat('yyyy年M月d日 HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(widget.item.createTime));

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

            // 标题区
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 18, color: Color(0xFF91918E)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF37352F),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 26, top: 4),
                    child: Row(
                      children: [
                        Text(_dateStr,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF91918E))),
                        if (widget.item.industry.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.item.industry,
                              style: const TextStyle(fontSize: 11, color: AppColors.accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 工具栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ResultToolbar(
                content: _content,
                title: _title,
                screenshotKey: _screenshotKey,
              ),
            ),

            // 内容区
            Expanded(
              child: _content.isNotEmpty
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                      child: RepaintBoundary(
                        key: _screenshotKey,
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 截图时显示的头部
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('N',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16)),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('NivoWork',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF37352F),
                                          letterSpacing: -0.3)),
                                  const Spacer(),
                                  Text(_dateStr,
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF91918E))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(_title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF37352F))),
                              const SizedBox(height: 16),
                              MarkdownBody(
                                data: _content,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(
                                      fontSize: 14,
                                      height: 1.7,
                                      color: Color(0xFF37352F)),
                                  h1: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF37352F)),
                                  h2: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF37352F)),
                                  h3: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF37352F)),
                                  listBullet: const TextStyle(
                                      fontSize: 14, color: Color(0xFF37352F)),
                                  blockquoteDecoration: BoxDecoration(
                                    border: const Border(
                                        left: BorderSide(
                                            color: Color(0xFFE9E9E7), width: 3)),
                                    color: const Color(0xFFF7F7F5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0xFFF7F6F3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  codeblockPadding: const EdgeInsets.all(12),
                                  horizontalRuleDecoration: const BoxDecoration(
                                    border: Border(
                                        top: BorderSide(color: Color(0xFFE9E9E7))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text('暂无内容',
                          style: TextStyle(fontSize: 14, color: Color(0xFF91918E))),
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
