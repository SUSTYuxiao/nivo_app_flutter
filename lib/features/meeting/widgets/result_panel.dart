import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/nivo_button.dart';
import '../../../shared/widgets/result_toolbar.dart';
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
              const SizedBox(height: 12),
              ResultToolbar(
                content: content,
                title: '会议纪要',
                screenshotKey: _screenshotKey,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _screenshotKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: MarkdownBody(data: content),
                    ),
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
