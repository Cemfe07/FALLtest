import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class MysticBackground extends StatefulWidget {
  final Widget child;
  final double scrimOpacity;
  final double patternOpacity;

  const MysticBackground({
    super.key,
    required this.child,
    this.scrimOpacity = 0.60,
    this.patternOpacity = 0.10,
  });

  @override
  State<MysticBackground> createState() => _MysticBackgroundState();
}

class _MysticBackgroundState extends State<MysticBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.linear);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
        final patternOpacity = (widget.patternOpacity * (0.7 + 0.3 * pulse)).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 🔮 Background image
            Image.asset(
              'assets/backgrounds/ChatGPT Image 3 Oca 2026 18_20_30.png',
              fit: BoxFit.cover,
            ),

            // ✨ Canlı gradient overlay (hafif renk nabzı)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.3 + 0.2 * pulse, 0.2),
                      radius: 1.2 + 0.15 * pulse,
                      colors: [
                        Colors.transparent,
                        AppColors.gold.withOpacity(0.03 + 0.04 * pulse),
                        AppColors.aiAccent.withOpacity(0.02 + 0.03 * (1 - pulse)),
                        const Color(0xFF2A1642).withOpacity(0.04 + 0.03 * pulse),
                      ],
                      stops: const [0.35, 0.6, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 🖤 Readability scrim
            Container(color: Colors.black.withOpacity(widget.scrimOpacity)),

            // ☁️ Floating nebula orbs
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _NebulaOrbsPainter(t),
                ),
              ),
            ),

            // ✨ Pattern overlay (nabız ile opaklık)
            if (patternOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: patternOpacity,
                    child: CustomPaint(
                      painter: _MysticPatternPainter(),
                    ),
                  ),
                ),
              ),

            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TwinklePainter(t),
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ShootingStarsPainter(t),
                ),
              ),
            ),

            // 🌒 Vignette
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.15,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.55, 1.0],
                ),
              ),
            ),

            widget.child,
          ],
        );
      },
    );
  }
}

/// Yıldız noktaları: zamanla parlayıp sönen
class _TwinklePainter extends CustomPainter {
  final double time;

  _TwinklePainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final dotPaint = ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.fill;

    for (int i = 0; i < 120; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final phase = (i * 0.13) % 1.0;
      final twinkle = 0.5 + 0.5 * math.sin((time + phase) * math.pi * 2);
      final opacity = (0.04 + 0.14 * twinkle).clamp(0.0, 1.0);
      final r = 0.8 + rnd.nextDouble() * 1.8;

      dotPaint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter oldDelegate) =>
      oldDelegate.time != time;
}

class _NebulaOrbsPainter extends CustomPainter {
  final double time;
  _NebulaOrbsPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = <_NebOrb>[
      _NebOrb(0.18, 0.28, 0.10, const Color(0xFF6DD5FA), 0.045),
      _NebOrb(0.72, 0.62, 0.14, const Color(0xFFE040A0), 0.030),
      _NebOrb(0.48, 0.12, 0.07, const Color(0xFFFFD27D), 0.040),
      _NebOrb(0.85, 0.22, 0.10, const Color(0xFF4A2070), 0.050),
      _NebOrb(0.30, 0.78, 0.08, const Color(0xFF6DD5FA), 0.025),
    ];

    for (final orb in orbs) {
      final phase = orb.x + orb.y;
      final dx = orb.x * size.width +
          math.sin(time * math.pi * 2 * 0.6 + phase * 10) * 18;
      final dy = orb.y * size.height +
          math.cos(time * math.pi * 2 * 0.4 + phase * 8) * 14;
      final r = orb.radius * size.width;

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(dx, dy),
          r,
          [
            orb.color.withOpacity(orb.opacity),
            orb.color.withOpacity(0.0),
          ],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4);

      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NebulaOrbsPainter old) => old.time != time;
}

class _NebOrb {
  final double x, y, radius;
  final Color color;
  final double opacity;
  const _NebOrb(this.x, this.y, this.radius, this.color, this.opacity);
}

class _ShootingStarsPainter extends CustomPainter {
  final double time;
  _ShootingStarsPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(99);
    for (int i = 0; i < 5; i++) {
      final speed = 0.6 + rnd.nextDouble() * 0.5;
      final phase = (time * speed + i * 0.2) % 1.0;
      if (phase > 0.08) continue;

      final progress = phase / 0.08;
      final startX = rnd.nextDouble() * size.width * 0.7;
      final startY = rnd.nextDouble() * size.height * 0.4;
      final angle = 0.3 + rnd.nextDouble() * 0.4;
      final len = 70 + rnd.nextDouble() * 100;

      final cx = startX + math.cos(angle) * len * progress;
      final cy = startY + math.sin(angle) * len * progress;
      final tailLen = 40 * (1 - progress * 0.3);
      final tx = cx - math.cos(angle) * tailLen;
      final ty = cy - math.sin(angle) * tailLen;
      final op = (0.4 * (1 - progress)).clamp(0.0, 1.0);

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(tx, ty),
          Offset(cx, cy),
          [Colors.transparent, Colors.white.withOpacity(op)],
        )
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(tx, ty), Offset(cx, cy), paint);

      final glow = Paint()
        ..color = Colors.white.withOpacity(op * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(cx, cy), 1.5, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _ShootingStarsPainter old) => old.time != time;
}

class _MysticPatternPainter extends CustomPainter {
  final ui.Paint _paint = ui.Paint()
    ..isAntiAlias = true
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final seed = 42;
    final rnd = math.Random(seed);

    _paint.color = Colors.white.withOpacity(0.10);

    final center = Offset(size.width * 0.5, size.height * 0.45);
    final baseR = math.min(size.width, size.height) * 0.35;
    for (int i = 0; i < 4; i++) {
      final r = baseR + i * (baseR * 0.12);
      canvas.drawCircle(center, r, _paint);
    }

    for (int i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final len = 18 + rnd.nextDouble() * 22;
      final ang = rnd.nextDouble() * math.pi * 2;
      final p1 = Offset(x, y);
      final p2 = Offset(x + math.cos(ang) * len, y + math.sin(ang) * len);
      canvas.drawLine(p1, p2, _paint);
    }

    final dotPaint = ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.10);

    for (int i = 0; i < 140; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.6 + rnd.nextDouble() * 1.6;
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }

    final gridPaint = ui.Paint()
      ..isAntiAlias = true
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withOpacity(0.06);

    const step = 120.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
