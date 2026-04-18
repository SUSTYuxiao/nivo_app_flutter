import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import '../../core/services/api_service.dart';
import 'charge_page.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  Map<String, dynamic>? _vipData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVipInfo();
  }

  Future<void> _loadVipInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final api = context.read<ApiService>();
      final data = await api.getVipExpire(user.id);
      if (mounted) setState(() { _vipData = data; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _productName {
    final type = _vipData?['productTypeCur'] ?? '';
    switch (type) {
      case 'vip1': return 'Pro Lite';
      case 'vip2': return 'Pro';
      case 'vip3': return 'Power';
      default: return '免费用户';
    }
  }

  bool get _isFree => _vipData?['isFree'] == true || _vipData?['productTypeCur'] == null || _vipData?['productTypeCur'] == '';

  String get _expireText {
    final expire = _vipData?['expireTimeCur'];
    if (expire == null || _isFree) return '';
    final expireDate = DateTime.fromMillisecondsSinceEpoch(expire is int ? expire : int.tryParse(expire.toString()) ?? 0);
    final remaining = expireDate.difference(DateTime.now()).inDays;
    if (remaining < 0) return '已过期';
    return '剩余 $remaining 天 · ${expireDate.month}/${expireDate.day} 到期';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 导航栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF91918E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        // 头像 + 邮箱
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  email.isNotEmpty ? email[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.accent),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF37352F))),
                              const SizedBox(height: 4),
                              Text('UID: ${user?.id.substring(0, 8) ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF91918E))),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 会员卡片
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: _isFree
                                ? const LinearGradient(colors: [Color(0xFFF7F7F5), Color(0xFFEEEEEC)])
                                : const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _isFree ? const Color(0xFFE0E0DE) : const Color(0xFFFFD700).withAlpha(40),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _productName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _isFree ? const Color(0xFF73726E) : const Color(0xFFFFD700),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!_isFree)
                                    Text(_expireText, style: const TextStyle(fontSize: 12, color: Color(0xFF91918E))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isFree ? '升级会员，解锁更多功能' : '感谢您的支持',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _isFree ? const Color(0xFF37352F) : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChargePage())),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isFree ? AppColors.accent : const Color(0xFFFFD700),
                                    foregroundColor: _isFree ? Colors.white : Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  child: Text(_isFree ? '开通会员' : '续费 / 升级'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 套餐一览
                        const Text('套餐一览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                        const SizedBox(height: 16),

                        _PlanOverviewCard(
                          name: 'Pro Lite',
                          price: '¥19',
                          period: '/月',
                          features: const ['会后整理 无限次', '实时会议 5小时/月', '基础功能'],
                          isCurrentPlan: _vipData?['productTypeCur'] == 'vip1',
                        ),
                        const SizedBox(height: 12),
                        _PlanOverviewCard(
                          name: 'Pro',
                          price: '¥29',
                          period: '/月',
                          features: const ['会后整理 无限次', '实时会议 20小时/月', '高级功能'],
                          isHighlighted: true,
                          isCurrentPlan: _vipData?['productTypeCur'] == 'vip2',
                        ),
                        const SizedBox(height: 12),
                        _PlanOverviewCard(
                          name: 'Power',
                          price: '¥49',
                          period: '/月',
                          features: const ['会后整理 无限次', '实时会议 无限', '全部功能'],
                          isCurrentPlan: _vipData?['productTypeCur'] == 'vip3',
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanOverviewCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final List<String> features;
  final bool isHighlighted;
  final bool isCurrentPlan;

  const _PlanOverviewCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    this.isHighlighted = false,
    this.isCurrentPlan = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.accent.withAlpha(8) : const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlan
              ? AppColors.accent
              : isHighlighted
                  ? AppColors.accent.withAlpha(40)
                  : const Color(0xFFE9E9E7),
          width: isCurrentPlan ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('当前', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded, size: 14, color: Color(0xFF91918E)),
                          const SizedBox(width: 6),
                          Text(f, style: const TextStyle(fontSize: 12, color: Color(0xFF73726E))),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
              Text(period, style: const TextStyle(fontSize: 12, color: Color(0xFF91918E))),
            ],
          ),
        ],
      ),
    );
  }
}
