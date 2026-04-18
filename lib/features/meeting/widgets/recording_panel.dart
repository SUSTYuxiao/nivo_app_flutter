import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/industry_template_dialog.dart';
import '../meeting_provider.dart';

class RecordingPanel extends StatelessWidget {
  const RecordingPanel({super.key});

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeetingProvider>(
      builder: (context, meeting, _) {
        return Column(
          children: [
            const SizedBox(height: 16),
            const _RecordingIndicator(),
            const SizedBox(height: 8),
            Text(
              _formatDuration(meeting.elapsed),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '实时转录中',
                style: TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: meeting.transcriptions.isEmpty
                    ? Center(
                        child: Text('等待语音输入...',
                            style:
                                TextStyle(color: Colors.grey.shade400)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        itemCount: meeting.transcriptions.length,
                        itemBuilder: (context, index) {
                          final t = meeting.transcriptions[
                              meeting.transcriptions.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              t.text,
                              style: TextStyle(
                                fontSize: 15,
                                color: t.isFinal
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (meeting.isGenerating)
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    CircularProgressIndicator.adaptive(),
                    SizedBox(height: 8),
                    Text('正在生成纪要...'),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: GestureDetector(
                  onTap: () async {
                    // Pause timer while dialog is open
                    meeting.pauseTimer();
                    final result = await showIndustryTemplateDialog(context);
                    if (result != null && context.mounted) {
                      context.read<MeetingProvider>().endMeeting(
                            industry: result.industry,
                            template: result.template,
                          );
                    } else {
                      // User cancelled, resume timer
                      meeting.resumeTimer();
                    }
                  },
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.recording,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '结束会议',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            if (meeting.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  meeting.errorMessage!,
                  style:
                      const TextStyle(color: AppColors.recording, fontSize: 13),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator();

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 1.0 + _ctrl.value * 0.3;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.recording
                  .withAlpha((200 + 55 * _ctrl.value).toInt()),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
