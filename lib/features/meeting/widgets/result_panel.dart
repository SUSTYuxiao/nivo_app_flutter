import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/minutes_card.dart';
import '../../../shared/widgets/nivo_button.dart';
import '../meeting_provider.dart';

class ResultPanel extends StatefulWidget {
  const ResultPanel({super.key});

  @override
  State<ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<ResultPanel> {
  final _screenshotKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, meeting, _) {
        final content = meeting.meetingResult ?? '';
        return Column(
          children: [
            Expanded(
              child: (meeting.isGenerating && content.trim().isEmpty)
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'AI 正在生成纪要...',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : (!meeting.isGenerating && content.trim().isEmpty && meeting.errorMessage != null)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                meeting.errorMessage!,
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : MinutesCard(
                          title: '会议纪要',
                          content: content,
                          screenshotKey: _screenshotKey,
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
        );
      },
    );
  }
}
