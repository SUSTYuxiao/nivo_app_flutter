import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../shared/widgets/industry_template_dialog.dart';
import '../../shared/widgets/nivo_button.dart';
import '../../shared/widgets/processing_view.dart';
import '../../shared/widgets/result_toolbar.dart';
import '../settings/settings_provider.dart';
import 'after_meet_provider.dart';
import 'recordings_list_page.dart';

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
              return ProcessingView(
                progress: provider.progress,
                status: provider.progressStatus.isNotEmpty
                    ? provider.progressStatus
                    : '正在生成...',
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
    return Stack(
      children: [
        Center(
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
                '选择录音开始会后整理',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: AppColors.recording, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 40),
              NivoButton(
                label: '开始整理',
                width: 200,
                onTap: () => _pickAndSubmit(context),
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 20,
          child: GestureDetector(
            onTap: () => _pickAndSubmit(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.audio_file, size: 16, color: AppColors.accent),
                  SizedBox(width: 6),
                  Text('历史录音',
                      style: TextStyle(fontSize: 13, color: AppColors.accent)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndSubmit(BuildContext context) async {
    final paths = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const RecordingsListPage(),
      ),
    );
    if (paths != null && paths.isNotEmpty && context.mounted) {
      for (final p in paths) {
        provider.addLocalRecording(p);
      }
      if (context.mounted) {
        _showInputSheet(context, provider);
      }
    }
  }

  void _showInputSheet(BuildContext context, AfterMeetProvider provider) {
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
              const Text('确认内容',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Selected files
                    if (provider.audioFilePaths.isNotEmpty) ...[
                      Text('已选录音',
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
                              IconButton(
                                onPressed: () => provider.removeAudioFile(entry.key),
                                icon: const Icon(Icons.close, size: 16, color: AppColors.neutral),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    // Text input
                    Text('补充文本（可选）',
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
                          hintText: '粘贴或输入补充内容...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
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
                height: 48,
                child: CupertinoButton(
                  onPressed: () async {
                    final result = await showIndustryTemplateDialog(context);
                    if (result != null && context.mounted) {
                      final mode = context.read<SettingsProvider>().transcribeMode;
                      Navigator.pop(context); // close sheet
                      provider.submit(
                        industry: result.industry,
                        template: result.template,
                        transcribeMode: mode,
                      );
                    }
                  },
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(24),
                  padding: EdgeInsets.zero,
                  child: const Text('提交整理',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultView extends StatefulWidget {
  final AfterMeetProvider provider;
  const _ResultView({required this.provider});

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  final _screenshotKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final content = widget.provider.result ?? '';
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
                onTap: widget.provider.reset,
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ResultToolbar(
            content: content,
            title: '整理结果',
            screenshotKey: _screenshotKey,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: RepaintBoundary(
              key: _screenshotKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: MarkdownBody(data: content),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
