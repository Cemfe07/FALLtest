import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class MysticLoadingIndicator extends StatefulWidget {
  final String message;
  final String? submessage;
  final double size;

  const MysticLoadingIndicator({
    super.key,
    this.message = 'Hazırlanıyor…',
    this.submessage,
    this.size = 120,
  });

  @override
  State<MysticLoadingIndicator> createState() =>
      _MysticLoadingIndicatorState();
}

class _MysticLoadingIndicatorState extends State<MysticLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _orbitCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _textCtrl;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void didUpdateWidget(MysticLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.submessage != widget.submessage) {
      _textCtrl.reset();
      _textCtrl.forward();
    }
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_orbitCtrl, _pulseCtrl]),
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbitalPainter(
                  orbitProgress: _orbitCtrl.value,
                  pulseProgress: _pulseCtrl.value,
                ),
              );
            },
          ),
        ),
        if (widget.message.isNotEmpty) ...[
          const SizedBox(height: 28),
          FadeTransition(
            opacity:
                CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
            child: Column(
              children: [
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.submessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.submessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double orbitProgress;
  final double pulseProgress;

  _OrbitalPainter({required this.orbitProgress, required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final glowR = maxR * 0.22 + maxR * 0.06 * pulseProgress;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.gold.withOpacity(0.45 + 0.2 * pulseProgress),
          AppColors.gold.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: glowR * 2.5));
    canvas.drawCircle(center, glowR * 2.5, glowPaint);

    final centerPaint = Paint()
      ..color = AppColors.gold.withOpacity(0.80 + 0.20 * pulseProgress)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, glowR * 0.55, centerPaint);

    for (int ring = 0; ring < 3; ring++) {
      final ringR = maxR * (0.38 + ring * 0.22);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = AppColors.gold.withOpacity(0.06 + 0.03 * (2 - ring));
      canvas.drawCircle(center, ringR, ringPaint);
    }

    const dotCount = 8;
    for (int i = 0; i < dotCount; i++) {
      final ring = i % 3;
      final orbitR = maxR * (0.38 + ring * 0.22);
      final speed = 1.0 + ring * 0.35;
      final angle = (orbitProgress * speed + i / dotCount) * 2 * math.pi;

      final dotX = center.dx + math.cos(angle) * orbitR;
      final dotY = center.dy + math.sin(angle) * orbitR;

      final dotSize = 2.8 + (ring == 0 ? 1.2 : 0.0);
      final twinkle =
          0.5 + 0.5 * math.sin(orbitProgress * math.pi * 4 + i * 1.3);
      final opacity = (0.35 + 0.45 * twinkle).clamp(0.0, 1.0);

      Color dotColor;
      if (ring == 0) {
        dotColor = AppColors.gold.withOpacity(opacity);
      } else if (ring == 1) {
        dotColor = AppColors.aiAccent.withOpacity(opacity * 0.75);
      } else {
        dotColor = Colors.white.withOpacity(opacity * 0.55);
      }

      final dotPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dotX, dotY), dotSize, dotPaint);

      if (ring == 0) {
        final glowDotPaint = Paint()
          ..color = dotColor.withOpacity(opacity * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(Offset(dotX, dotY), dotSize * 2.2, glowDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter old) =>
      old.orbitProgress != orbitProgress || old.pulseProgress != pulseProgress;
}
