import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'meeting_provider.dart';
import 'widgets/prepare_panel.dart';
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
              MeetingPhase.prepare => const PreparePanel(),
              MeetingPhase.recording => const RecordingPanel(),
              MeetingPhase.result => const ResultPanel(),
            };
          },
        ),
      ),
    );
  }
}
