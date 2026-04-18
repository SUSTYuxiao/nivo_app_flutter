import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/vip_provider.dart';
import '../../shared/widgets/nivo_button.dart';
import '../settings/charge_page.dart';
import 'meeting_provider.dart';
import 'widgets/recording_panel.dart';
import 'widgets/result_panel.dart';

class MeetingPage extends StatelessWidget {
  const MeetingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<MeetingProvider>(
          builder: (context, meeting, _) {
            return switch (meeting.phase) {
              MeetingPhase.idle => _IdleView(onStart: () => meeting.startMeeting()),
              MeetingPhase.recording => const RecordingPanel(),
              MeetingPhase.result => const ResultPanel(),
            };
          },
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final VoidCallback onStart;
  const _IdleView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, meeting, _) {
        final vip = context.watch<VipProvider>();
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '实时会议',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '点击下方按钮开始录音和实时转录',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('全局收音',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('对外部扬声器做转写，适用线上会议',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: meeting.globalCapture,
                        onChanged: (v) {
                          if (v && !vip.isVip) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('会员功能'),
                                content: const Text('全局收音为会员功能，需至少 Pro Lite 会员'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.push(context,
                                          MaterialPageRoute(builder: (_) => const ChargePage()));
                                    },
                                    child: const Text('去开通'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          meeting.setGlobalCapture(v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              NivoButton(
                label: '发起会议',
                width: 200,
                onTap: onStart,
              ),
            ],
          ),
        );
      },
    );
  }
}
