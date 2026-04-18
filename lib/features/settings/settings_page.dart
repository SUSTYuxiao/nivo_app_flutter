import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/services/vip_provider.dart';
import '../login/login_provider.dart';
import 'settings_provider.dart';
import 'user_detail_page.dart';

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
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        context.read<VipProvider>().fetchVipStatus(user.id);
      }
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
                // 个人信息入口
                _card(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserDetailPage())),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Builder(builder: (_) {
                              final email = Supabase.instance.client.auth.currentUser?.email ?? '';
                              return Text(
                                email.isNotEmpty ? email[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.accent),
                              );
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Supabase.instance.client.auth.currentUser?.email ?? '',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Consumer<VipProvider>(
                                  builder: (context, vip, _) {
                                    final label = vip.isFree ? '免费用户' : (vip.productName.isNotEmpty ? vip.productName : '会员');
                                    return Text(label, style: TextStyle(
                                      fontSize: 12,
                                      color: vip.isFree ? const Color(0xFF91918E) : AppColors.accent,
                                      fontWeight: vip.isFree ? FontWeight.normal : FontWeight.w500,
                                    ));
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.neutral, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _card(
                  child: _tileRow(
                    label: '退出登录',
                    trailing: const Icon(Icons.chevron_right, color: AppColors.neutral),
                    onTap: () => context.read<LoginProvider>().signOut(),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('语音识别'),
                const SizedBox(height: 8),
                _card(
                  child: _tileRow(
                    label: '完全本地处理',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('开发中', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        const SizedBox(width: 8),
                        Switch.adaptive(
                          value: false,
                          onChanged: null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('关于'),
                const SizedBox(height: 8),
                _card(
                  child: _tileRow(label: '版本', trailing: const Text('1.0.0')),
                ),
                const SizedBox(height: 24),
                _sectionLabel('开发者'),
                const SizedBox(height: 8),
                _card(
                  child: Column(
                    children: [
                      _tileRow(
                        label: '开发者模式',
                        trailing: Switch.adaptive(
                          value: settings.devMode,
                          onChanged: (v) => settings.setDevMode(v),
                        ),
                      ),
                      if (settings.devMode)
                        _tileRow(
                          label: '模拟非会员',
                          trailing: Consumer<VipProvider>(
                            builder: (context, vip, _) => Switch.adaptive(
                              value: vip.devModeSimulateFree,
                              onChanged: (v) => vip.setDevModeSimulateFree(v),
                            ),
                          ),
                        ),
                    ],
                  ),
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
