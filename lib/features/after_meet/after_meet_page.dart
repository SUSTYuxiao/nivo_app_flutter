import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../shared/widgets/industry_template_dialog.dart';
import 'after_meet_provider.dart';

class AfterMeetPage extends StatelessWidget {
  const AfterMeetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AfterMeetProvider>(
          builder: (context, provider, _) {
            if (provider.result != null) {
              return _ResultView(provider: provider);
            }
            if (provider.isGenerating) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator.adaptive(),
                    SizedBox(height: 16),
                    Text('正在生成...', style: TextStyle(fontSize: 15)),
                  ],
                ),
              );
            }
            return _IdleView(provider: provider);
          },
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final AfterMeetProvider provider;
  const _IdleView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '会后整理',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '选择文件开始会后整理',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => _showInputSheet(context, provider),
            child: Container(
              width: 200,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(25),
              ),
              alignment: Alignment.center,
              child: const Text(
                '开始整理',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInputSheet(BuildContext context, AfterMeetProvider provider) {
    provider.loadLocalRecordings();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const _InputSheet(),
      ),
    );
  }
}

class _InputSheet extends StatefulWidget {
  const _InputSheet();

  @override
  State<_InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<_InputSheet> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showSyncGuide() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('从语音备忘录导入'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 打开「语音备忘录」App'),
            SizedBox(height: 8),
            Text('2. 长按录音，点击「分享」'),
            SizedBox(height: 8),
            Text('3. 选择「存储到文件」'),
            SizedBox(height: 8),
            Text('4. 回到 Nivo，点击「从文件选择」'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(AfterMeetProvider provider, String path, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除录音'),
        content: Text('确定删除 $name 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteLocalRecording(path);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Consumer<AfterMeetProvider>(
      builder: (context, provider, _) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('选择内容',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: _showSyncGuide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync, size: 14, color: AppColors.accent),
                          SizedBox(width: 4),
                          Text('从录音机同步',
                              style: TextStyle(fontSize: 12, color: AppColors.accent)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Text input
                    Text('会议文本（可选）',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _textController,
                        onChanged: provider.setInputText,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '粘贴或输入会议内容...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selected files
                    if (provider.audioFilePaths.isNotEmpty) ...[
                      Text('已选文件',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      ...provider.audioFilePaths.asMap().entries.map((entry) {
                        final fileName = entry.value.split('/').last;
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
                              Expanded(child: Text(fileName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                              GestureDetector(
                                onTap: () => provider.removeAudioFile(entry.key),
                                child: const Icon(Icons.close, size: 16, color: AppColors.neutral),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    // Local recordings
                    if (provider.localRecordings.isNotEmpty) ...[
                      Text('本地录音',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      ...provider.localRecordings.map((file) {
                        final name = file.path.split('/').last;
                        final stat = file.statSync();
                        final date = DateFormat('MM/dd HH:mm').format(stat.modified);
                        final sizeMb = (stat.size / 1024 / 1024).toStringAsFixed(1);
                        final isSelected = provider.audioFilePaths.contains(file.path);
                        return GestureDetector(
                          onTap: isSelected ? null : () => provider.addLocalRecording(file.path),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent.withAlpha(15) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.audio_file,
                                  size: 16,
                                  color: isSelected ? AppColors.accent : AppColors.neutral,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                      Text('$date · ${sizeMb}MB',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _confirmDelete(provider, file.path, name),
                                  child: const Icon(Icons.delete_outline, size: 16, color: AppColors.neutral),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                    // Pick from files
                    GestureDetector(
                      onTap: provider.pickAudioFile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 16, color: AppColors.accent),
                            SizedBox(width: 6),
                            Text('从文件选择', style: TextStyle(fontSize: 13, color: AppColors.accent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(provider.errorMessage!,
                      style: const TextStyle(color: AppColors.recording, fontSize: 13)),
                ),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    final result = await showIndustryTemplateDialog(context);
                    if (result != null && context.mounted) {
                      Navigator.pop(context); // close sheet
                      provider.submit(
                        industry: result.industry,
                        template: result.template,
                      );
                    }
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: const Text('提交整理',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultView extends StatelessWidget {
  final AfterMeetProvider provider;
  const _ResultView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('整理结果',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: provider.reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('新整理',
                      style: TextStyle(fontSize: 13, color: AppColors.accent)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Markdown(
              data: provider.result ?? '',
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
