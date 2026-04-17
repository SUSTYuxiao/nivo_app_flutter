import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/services/asr/asr_models.dart';
import '../login/login_provider.dart';
import 'settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // Refresh model download status when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().refreshModelStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 16),
                const Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('语音识别'),
                const SizedBox(height: 8),
                _card(
                  child: Column(
                    children: [
                      _tileRow(
                        label: 'ASR 模式',
                        trailing: SegmentedButton<AsrMode>(
                          segments: const [
                            ButtonSegment(value: AsrMode.cloud, label: Text('云端')),
                            ButtonSegment(value: AsrMode.local, label: Text('本地')),
                          ],
                          selected: {settings.asrMode},
                          onSelectionChanged: (v) => settings.setAsrMode(v.first),
                        ),
                      ),
                    ],
                  ),
                ),
                if (settings.asrMode == AsrMode.local) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('本地模型'),
                  const SizedBox(height: 8),
                  ...kAsrModels.map((model) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _modelCard(context, settings, model),
                      )),
                ],
                const SizedBox(height: 24),
                _sectionLabel('云端 API'),
                const SizedBox(height: 8),
                _card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: TextEditingController(text: settings.cloudApiBaseUrl),
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (v) => settings.setCloudApiBaseUrl(v),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('账户'),
                const SizedBox(height: 8),
                _card(
                  child: _tileRow(
                    label: '退出登录',
                    trailing: const Icon(Icons.chevron_right, color: AppColors.neutral),
                    onTap: () => context.read<LoginProvider>().signOut(),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('关于'),
                const SizedBox(height: 8),
                _card(
                  child: _tileRow(label: '版本', trailing: const Text('1.0.0')),
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _modelCard(
      BuildContext context, SettingsProvider settings, AsrModelInfo model) {
    final isDownloaded = settings.isModelDownloaded(model.id);
    final isDownloading =
        settings.isDownloadingModel && settings.downloadingModelId == model.id;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(model.sizeLabel,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500)),
                if (model.isRecommended) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('推荐',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.accent)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(model.description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: settings.modelDownloadProgress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '下载中 ${(settings.modelDownloadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ] else if (isDownloaded) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  const Text('已下载',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.success)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _confirmDelete(context, settings, model),
                    child: const Text('删除',
                        style: TextStyle(fontSize: 13, color: Colors.red)),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => settings.startModelDownload(model.id),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('下载模型'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, SettingsProvider settings, AsrModelInfo model) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除模型'),
        content: Text('确定删除 ${model.name} 吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              settings.deleteModel(model.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _tileRow({
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
