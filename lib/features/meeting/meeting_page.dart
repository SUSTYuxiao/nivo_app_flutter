import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
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
          const SizedBox(height: 40),
          GestureDetector(
            onTap: onStart,
            child: Container(
              width: 200,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(25),
              ),
              alignment: Alignment.center,
              child: const Text(
                '发起会议',
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
}
