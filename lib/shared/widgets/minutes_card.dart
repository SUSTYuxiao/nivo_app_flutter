import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import 'result_toolbar.dart';

/// 纪要展示卡片 — inmeet 结果页 & 历史详情页共用
class MinutesCard extends StatelessWidget {
  final String title;
  final String content;
  final DateTime? date;
  final String? industry;
  final GlobalKey screenshotKey;

  const MinutesCard({
    super.key,
    required this.title,
    required this.content,
    required this.screenshotKey,
    this.date,
    this.industry,
  });

  String get _dateStr => date != null
      ? DateFormat('yyyy年M月d日 HH:mm').format(date!)
      : '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题区
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined,
                      size: 18, color: Color(0xFF91918E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
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
              if (_dateStr.isNotEmpty || (industry != null && industry!.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 4),
                  child: Row(
                    children: [
                      if (_dateStr.isNotEmpty)
                        Text(_dateStr,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF91918E))),
                      if (industry != null && industry!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            industry!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.accent),
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
            content: content,
            title: title,
            screenshotKey: screenshotKey,
          ),
        ),

        // 内容区
        Expanded(
          child: content.isNotEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: RepaintBoundary(
                    key: screenshotKey,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 截图品牌头
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
                              if (_dateStr.isNotEmpty)
                                Text(_dateStr,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF91918E))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF37352F))),
                          const SizedBox(height: 16),
                          MarkdownBody(
                            data: content,
                            styleSheet: nivoMarkdownStyle(),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const Center(
                  child: Text('暂无内容',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFF91918E))),
                ),
        ),
      ],
    );
  }
}
