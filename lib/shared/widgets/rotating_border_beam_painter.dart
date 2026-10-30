import 'dart:math' as math;
import 'package:flutter/material.dart';

class RotatingBorderBeamPainter extends CustomPainter {
  final double progress;
  final Color borderColor;
  final double borderRadius;
  final double strokeWidth;

  RotatingBorderBeamPainter({
    required this.progress,
    required this.borderColor,
    this.borderRadius = 16.0,
    this.strokeWidth = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final halfStroke = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      halfStroke,
      halfStroke,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Full unbroken base border line
    final baseBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = borderColor.withOpacity(0.50);
    canvas.drawRRect(rrect, baseBorderPaint);

    // 2. Rotating luminous gradient wave
    final shader = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(progress * 2 * math.pi),
      colors: [
        borderColor.withOpacity(0.15),
        borderColor.withOpacity(0.55),
        borderColor,
        Colors.white,
        borderColor,
        borderColor.withOpacity(0.55),
        borderColor.withOpacity(0.15),
      ],
      stops: const [0.0, 0.30, 0.45, 0.50, 0.55, 0.70, 1.0],
    ).createShader(rect);

    // 3. Subtle outer glow pass
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..shader = shader;
    canvas.drawRRect(rrect, glowPaint);

    // 4. Rotating highlight beam on top of the full border
    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = shader;
    canvas.drawRRect(rrect, beamPaint);
  }

  @override
  bool shouldRepaint(RotatingBorderBeamPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

