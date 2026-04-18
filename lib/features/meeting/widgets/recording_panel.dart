import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../shared/widgets/industry_template_dialog.dart';
import '../../../shared/widgets/processing_view.dart';
import '../meeting_provider.dart';

enum _EndAction { submit, discard, cancel }

Future<_EndAction?> _showEndMeetingDialog(BuildContext context) {
  return showModalBottomSheet<_EndAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('结束会议', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              onPressed: () => Navigator.pop(context, _EndAction.submit),
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(24),
              child: const Text('生成会议纪要',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              onPressed: () => Navigator.pop(context, _EndAction.discard),
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              child: const Text('放弃总结',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: () => Navigator.pop(context, _EndAction.cancel),
            child: const Text('继续录音', style: TextStyle(fontSize: 14, color: AppColors.neutral)),
          ),
        ],
      ),
    ),
  );
}

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
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: ProcessingView(
                  progress: 0,
                  status: meeting.generatingStatus.isNotEmpty
                      ? meeting.generatingStatus
                      : '正在生成纪要...',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pause / Resume button
                    CupertinoButton(
                      onPressed: () {
                        if (meeting.isPaused) {
                          meeting.resumeTimer();
                        } else {
                          meeting.pauseTimer();
                        }
                      },
                      padding: EdgeInsets.zero,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          meeting.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 24,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // End meeting button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        meeting.pauseTimer();
                        final action = await _showEndMeetingDialog(context);
                        if (!context.mounted) return;
                        if (action == _EndAction.submit) {
                          final result = await showIndustryTemplateDialog(context);
                          if (result != null && context.mounted) {
                            context.read<MeetingProvider>().endMeeting(
                                  industry: result.industry,
                                  template: result.template,
                                );
                          } else {
                            meeting.resumeTimer();
                          }
                        } else if (action == _EndAction.discard) {
                          meeting.reset();
                        } else {
                          meeting.resumeTimer();
                        }
                      },
                      child: Container(
                        width: 140,
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
                  ],
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
