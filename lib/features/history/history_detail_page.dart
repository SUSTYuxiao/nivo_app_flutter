import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/models/history_item.dart';
import 'history_provider.dart';

class HistoryDetailPage extends StatelessWidget {
  final HistoryItem item;
  const HistoryDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.createTime);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'rename') {
                        _showRenameDialog(context);
                      } else if (action == 'delete') {
                        _showDeleteDialog(context);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'rename', child: Text('修改标题')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除',
                            style: TextStyle(color: AppColors.recording)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : '未命名会议',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(date),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      if (item.industry.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.industry,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: MarkdownBody(
                      data: item.result.isNotEmpty
                          ? item.result
                          : '暂无纪要内容',
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: item.title);
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              context
                  .read<HistoryProvider>()
                  .updateTitle(item.id, ctrl.text.trim());
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              context.read<HistoryProvider>().deleteItem(item.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('删除',
                style: TextStyle(color: AppColors.recording)),
          ),
        ],
      ),
    );
  }
}
