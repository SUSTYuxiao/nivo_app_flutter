import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/nivo_button.dart';
import '../meeting_provider.dart';

class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, meeting, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                '会议纪要',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Markdown(
                    data: meeting.meetingResult ?? '暂无内容',
                    shrinkWrap: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: NivoButton(
                  label: '返回',
                  width: 200,
                  onTap: () => meeting.reset(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
