import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';

class ProcessingView extends StatefulWidget {
  final double progress;
  final String status;
  final ProcessingStage stage;

  const ProcessingView({
    super.key,
    required this.progress,
    required this.status,
    this.stage = ProcessingStage.idle,
  });

  @override
  State<ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<ProcessingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 是否显示确定进度弧形（有真实或假进度的阶段）
  bool get _showDeterminate {
    switch (widget.stage) {
      case ProcessingStage.uploading:
      case ProcessingStage.cloudTranscribing:
      case ProcessingStage.localTranscribing:
        return widget.progress > 0;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: _showDeterminate ? widget.progress : 0.0,
                    animValue: _ctrl.value,
                    color: AppColors.accent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.status,
              key: ValueKey(widget.status),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          if (_showDeterminate && widget.progress > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  backgroundColor: Colors.grey.shade200,
                  color: AppColors.accent,
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(widget.progress * 100).toInt()}%',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double animValue;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.animValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withAlpha(25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, bgPaint);

    // Animated arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (progress > 0) {
      // Determinate: show progress arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        arcPaint,
      );
    } else {
      // Indeterminate: spinning arc
      final startAngle = 2 * pi * animValue - pi / 2;
      final sweepAngle = pi * 0.8 + sin(animValue * 2 * pi) * pi * 0.3;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    // Pulsing dot
    final iconPaint = Paint()..color = color;
    final dotRadius = 4.0 + sin(animValue * 2 * pi) * 1.5;
    canvas.drawCircle(center, dotRadius, iconPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.animValue != animValue;
}
