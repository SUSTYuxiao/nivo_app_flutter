import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import 'history_provider.dart';
import 'history_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<HistoryProvider>();
      if (provider.items.isEmpty) provider.loadMore();
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<HistoryProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<HistoryProvider>(
          builder: (context, history, _) {
            return RefreshIndicator(
              onRefresh: () => history.refresh(),
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '会议历史',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _TimeFilterChips(
                            selected: history.timeRange,
                            onSelected: (v) => history.setTimeRange(v),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (history.items.isEmpty && !history.isLoading)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          '暂无会议记录',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index >= history.items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child:
                                        CircularProgressIndicator.adaptive()),
                              );
                            }
                            final item = history.items[index];
                            final date = DateTime.fromMillisecondsSinceEpoch(
                                item.createTime);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HistoryDetailPage(item: item),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title.isNotEmpty
                                                  ? item.title
                                                  : '未命名会议',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('yyyy-MM-dd HH:mm')
                                                  .format(date),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (item.industry.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.accent.withAlpha(25),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.industry,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.accent),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: history.items.length +
                              (history.isLoading ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimeFilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _TimeFilterChips(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('today', '今天'),
      ('7days', '7天内'),
      ('30days', '30天内'),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (value, label) in filters)
          GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    selected == value ? AppColors.accent : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      selected == value ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
