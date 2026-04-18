import 'package:flutter/material.dart';

/// Shimmer skeleton placeholder for loading states.
class SkeletonLine extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLine({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<SkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
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
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-1.0 + 2.0 * _ctrl.value + 1.0, 0),
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton card mimicking a history list item.
class SkeletonHistoryCard extends StatelessWidget {
  const SkeletonHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLine(width: 200, height: 18),
          SizedBox(height: 10),
          SkeletonLine(width: 140, height: 14),
          SizedBox(height: 8),
          SkeletonLine(width: 80, height: 12),
        ],
      ),
    );
  }
}
