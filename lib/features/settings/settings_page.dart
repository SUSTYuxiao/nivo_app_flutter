import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import 'settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                    onTap: () {
                      // Will be wired to AuthService.signOut in Task 8
                    },
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
