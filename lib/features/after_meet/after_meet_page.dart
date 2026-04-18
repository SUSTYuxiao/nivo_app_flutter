import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
            return _InputView(provider: provider);
          },
        ),
      ),
    );
  }
}

class _InputView extends StatefulWidget {
  final AfterMeetProvider provider;
  const _InputView({required this.provider});

  @override
  State<_InputView> createState() => _InputViewState();
}

class _InputViewState extends State<_InputView> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.provider.inputText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 16),
              const Text(
                '会后整理',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Text('会议文本',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _textController,
                  onChanged: provider.setInputText,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '粘贴或输入会议内容...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('音频文件',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              ...provider.audioFilePaths.asMap().entries.map((entry) {
                final fileName = entry.value.split('/').last;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.audio_file, size: 20, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(fileName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                      ),
                      GestureDetector(
                        onTap: () => provider.removeAudioFile(entry.key),
                        child: const Icon(Icons.close, size: 18, color: AppColors.neutral),
                      ),
                    ],
                  ),
                );
              }),
              GestureDetector(
                onTap: provider.pickAudioFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: AppColors.accent),
                      SizedBox(width: 6),
                      Text('选择音频文件',
                          style:
                              TextStyle(fontSize: 14, color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(provider.errorMessage!,
                    style: const TextStyle(
                        color: AppColors.recording, fontSize: 13)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: provider.isGenerating
              ? const Column(
                  children: [
                    CircularProgressIndicator.adaptive(),
                    SizedBox(height: 8),
                    Text('正在生成...'),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      final result =
                          await showIndustryTemplateDialog(context);
                      if (result != null && context.mounted) {
                        context.read<AfterMeetProvider>().submit(
                              industry: result.industry,
                              template: result.template,
                            );
                      }
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: const Text('开始整理',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
        ),
      ],
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
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: provider.reset,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('新整理',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.accent)),
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
