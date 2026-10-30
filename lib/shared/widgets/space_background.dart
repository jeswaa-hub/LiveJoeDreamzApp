import 'dart:math';
import 'package:flutter/material.dart';

class SpaceBackground extends StatelessWidget {
  final Widget child;
  final AnimationController? driftController;
  final AnimationController? twinkleController;

  const SpaceBackground({
    super.key,
    required this.child,
    this.driftController,
    this.twinkleController,
  });

  @override
  Widget build(BuildContext context) {
    if (driftController != null && twinkleController != null) {
      return AnimatedBuilder(
        animation: Listenable.merge([driftController!, twinkleController!]),
        builder: (context, _) {
          return CustomPaint(
            painter: SpacePainter(
              drift: driftController!.value,
              twinkle: twinkleController!.value,
            ),
            child: child,
          );
        },
      );
    }
    return CustomPaint(
      painter: SpacePainter(drift: 0, twinkle: 0),
      child: child,
    );
  }
}

class SpacePainter extends CustomPainter {
  final double drift;
  final double twinkle;
  SpacePainter({required this.drift, required this.twinkle});

  static const Color _cyan = Color(0xFF00DBE9);
  static final List<Star> _stars = _generateStars();

  static List<Star> _generateStars() {
    final rng = Random(42);
    final stars = <Star>[];
    for (int i = 0; i < 50; i++) {
      stars.add(Star(
        x: rng.nextDouble(), y: rng.nextDouble(),
        radius: 0.5 + rng.nextDouble() * 0.3,
        baseOpacity: 0.15 + rng.nextDouble() * 0.3,
        speed: 0.2 + rng.nextDouble() * 0.3,
        twinklePhase: rng.nextDouble(),
        color: Colors.white,
      ));
    }
    for (int i = 0; i < 15; i++) {
      stars.add(Star(
        x: rng.nextDouble(), y: rng.nextDouble(),
        radius: 0.8 + rng.nextDouble() * 0.4,
        baseOpacity: 0.3 + rng.nextDouble() * 0.3,
        speed: 0.3 + rng.nextDouble() * 0.5,
        twinklePhase: rng.nextDouble(),
        color: Colors.white,
      ));
    }
    final colors = [Colors.white, _cyan, const Color(0xFFFBBF24)];
    for (int i = 0; i < 5; i++) {
      stars.add(Star(
        x: rng.nextDouble(), y: rng.nextDouble(),
        radius: 1.2 + rng.nextDouble() * 0.5,
        baseOpacity: 0.5 + rng.nextDouble() * 0.3,
        speed: 0.5 + rng.nextDouble() * 0.8,
        twinklePhase: rng.nextDouble(),
        color: colors[i % colors.length],
      ));
    }
    return stars;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF030914),
          Color(0xFF051222),
          Color(0xFF09182E),
          Color(0xFF061426),
          Color(0xFF030914),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Balanced cosmic nebulae distributed smoothly across full screen height
    _drawNebula(canvas, size, size.width * 0.15, size.height * 0.15, 260, const Color(0xFF0D2542), 0.28);
    _drawNebula(canvas, size, size.width * 0.85, size.height * 0.38, 280, const Color(0xFF142445), 0.24);
    _drawNebula(canvas, size, size.width * 0.50, size.height * 0.60, 300, _cyan, 0.05);
    _drawNebula(canvas, size, size.width * 0.80, size.height * 0.82, 280, const Color(0xFF0E223D), 0.26);
    _drawNebula(canvas, size, size.width * 0.20, size.height * 0.95, 260, const Color(0xFF081C33), 0.25);

    final paint = Paint();
    for (final star in _stars) {
      final driftOffset = (drift * star.speed) % 1.0;
      final sy = (star.y - driftOffset + 1.0) % 1.0;
      final twinkleVal = (sin((twinkle * pi * 2) + (star.twinklePhase * pi * 2)) + 1) / 2;
      final opacity = star.baseOpacity * (0.6 + twinkleVal * 0.4);
      canvas.drawCircle(
        Offset(star.x * size.width, sy * size.height),
        star.radius,
        paint..color = star.color.withOpacity(opacity),
      );
    }
  }

  void _drawNebula(Canvas canvas, Size size, double cx, double cy, double radius, Color color, double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  @override
  bool shouldRepaint(SpacePainter old) => old.drift != drift || old.twinkle != twinkle;
}

class Star {
  final double x, y, radius, baseOpacity, speed, twinklePhase;
  final Color color;
  Star({
    required this.x, required this.y,
    required this.radius, required this.baseOpacity,
    required this.speed, required this.twinklePhase,
    required this.color,
  });
}
