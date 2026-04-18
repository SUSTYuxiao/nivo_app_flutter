import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Primary action button — iOS style with continuous rounded rect.
class NivoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double? width;
  final Color? color;
  final Color? textColor;

  const NivoButton({
    super.key,
    required this.label,
    this.onTap,
    this.width,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 50,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        color: color ?? AppColors.accent,
        borderRadius: BorderRadius.circular(25),
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Secondary button — iOS style, light background.
class NivoButtonSecondary extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double? width;

  const NivoButtonSecondary({
    super.key,
    required this.label,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 50,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        color: AppColors.background,
        borderRadius: BorderRadius.circular(25),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
