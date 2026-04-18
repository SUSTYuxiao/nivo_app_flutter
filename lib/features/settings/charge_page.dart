import 'package:flutter/material.dart';

import '../../core/constants.dart';

class ChargePage extends StatelessWidget {
  const ChargePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF91918E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text('选择套餐', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 16),
                  _PriceCard(
                    name: 'Pro Lite',
                    price: '¥19',
                    originalPrice: '¥29',
                    period: '/月',
                    productType: 'vip1',
                    features: const [
                      ('会后整理', ['无限次会后整理', '基础模板']),
                      ('实时会议', ['5小时/月']),
                      ('基础功能', ['历史记录', '导出文本']),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PriceCard(
                    name: 'Pro',
                    price: '¥29',
                    originalPrice: '¥49',
                    period: '/月',
                    productType: 'vip2',
                    isRecommended: true,
                    features: const [
                      ('会后整理', ['无限次会后整理', '全部模板']),
                      ('实时会议', ['20小时/月']),
                      ('高级功能', ['历史记录', '导出文本', '导出图片']),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PriceCard(
                    name: 'Power',
                    price: '¥49',
                    originalPrice: '¥99',
                    period: '/月',
                    productType: 'vip3',
                    features: const [
                      ('会后整理', ['无限次会后整理', '全部模板', '自定义模板']),
                      ('实时会议', ['无限时长']),
                      ('全部功能', ['历史记录', '导出文本', '导出图片', '优先支持']),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '开通即表示同意《付费服务协议》和《会员权益说明》',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
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

class _PriceCard extends StatelessWidget {
  final String name;
  final String price;
  final String originalPrice;
  final String period;
  final String productType;
  final bool isRecommended;
  final List<(String, List<String>)> features;

  const _PriceCard({
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.period,
    required this.productType,
    required this.features,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRecommended ? AppColors.accent.withAlpha(6) : const Color(0xFFFAFAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended ? AppColors.accent.withAlpha(60) : const Color(0xFFE9E9E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
              if (isRecommended) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('推荐', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Color(0xFF37352F), height: 1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(period, style: const TextStyle(fontSize: 14, color: Color(0xFF91918E))),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  originalPrice,
                  style: const TextStyle(fontSize: 14, color: Color(0xFFB4B4B0), decoration: TextDecoration.lineThrough),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF91918E))),
                    const SizedBox(height: 4),
                    ...group.$2.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.check_rounded, size: 14, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text(f, style: const TextStyle(fontSize: 13, color: Color(0xFF37352F))),
                            ],
                          ),
                        )),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请在网页端完成支付'), duration: Duration(seconds: 2)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended ? AppColors.accent : const Color(0xFF37352F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('立即开通', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}
