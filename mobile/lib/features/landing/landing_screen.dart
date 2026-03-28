import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/gradient_button.dart';
import '../home/home_screen.dart';

class WelcomeLandingScreen extends StatefulWidget {
  const WelcomeLandingScreen({super.key});

  @override
  State<WelcomeLandingScreen> createState() => _WelcomeLandingScreenState();
}

class _WelcomeLandingScreenState extends State<WelcomeLandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _entranceCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _featuresOpacity;
  late Animation<double> _ctaOpacity;

  final List<_TapRipple> _ripples = [];

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.05, 0.28, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.05, 0.35, curve: Curves.easeOutBack),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.28, 0.52, curve: Curves.easeOut),
      ),
    );
    _featuresOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.48, 0.72, curve: Curves.easeOut),
      ),
    );
    _ctaOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.68, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    for (final r in _ripples) {
      r.controller.dispose();
    }
    _bgCtrl.dispose();
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final ripple = _TapRipple(position: details.localPosition, controller: ctrl);
    setState(() => _ripples.add(ripple));
    ctrl.forward().then((_) {
      if (mounted) {
        setState(() => _ripples.remove(ripple));
        ctrl.dispose();
      }
    });
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 700),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: GestureDetector(
        onTapDown: _onTapDown,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _LandingBgPainter(
                      time: _bgCtrl.value,
                      ripples: _ripples,
                    ),
                  );
                },
              ),
            ),

            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 1.2,
                  colors: [Colors.transparent, Color(0xCC0D0D1A)],
                  stops: [0.35, 1.0],
                ),
              ),
            ),

            SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge([_entranceCtrl, _pulseCtrl, _bgCtrl]),
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        _animatedLogo(),
                        const SizedBox(height: 14),
                        _animatedBadge(),
                        const SizedBox(height: 24),
                        _animatedTagline(),
                        const Spacer(flex: 2),
                        _animatedFeatures(),
                        const Spacer(flex: 1),
                        _animatedCTA(),
                        const SizedBox(height: 16),
                        _animatedHint(),
                        const SizedBox(height: 36),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedLogo() {
    return Opacity(
      opacity: _logoOpacity.value,
      child: Transform.scale(
        scale: _logoScale.value,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final shimmer = _bgCtrl.value;
            return LinearGradient(
              begin: Alignment(-1.0 + shimmer * 4, 0),
              end: Alignment(-0.5 + shimmer * 4, 0),
              colors: const [
                Color(0xFFFFE5A0),
                AppColors.gold,
                Colors.white,
                AppColors.gold,
                Color(0xFFFFE5A0),
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: const Text(
            'LunAura',
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedBadge() {
    return Opacity(
      opacity: _logoOpacity.value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.aiAccent.withOpacity(0.22),
            AppColors.aiAccent.withOpacity(0.08),
          ]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.aiAccent.withOpacity(0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: AppColors.aiAccent),
            const SizedBox(width: 6),
            Text(
              'AI destekli mistik rehberin',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.aiAccent,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedTagline() {
    return Opacity(
      opacity: _taglineOpacity.value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _taglineOpacity.value)),
        child: Column(
          children: [
            Text(
              'Kaderin, senin için hazır.',
              style: TextStyle(
                fontSize: 19,
                color: Colors.white.withOpacity(0.82),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '7+ analiz türü · Kişiselleştirilmiş AI yorumları',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedFeatures() {
    const features = [
      (Icons.coffee_outlined, 'Kahve Falı'),
      (Icons.pan_tool_outlined, 'El Falı'),
      (Icons.style_outlined, 'Tarot'),
      (Icons.auto_awesome_outlined, 'Numeroloji'),
      (Icons.public_outlined, 'Doğum Haritası'),
      (Icons.psychology_alt_outlined, 'Kişilik'),
      (Icons.favorite_outline, 'Sinastri'),
    ];

    return Opacity(
      opacity: _featuresOpacity.value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - _featuresOpacity.value)),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: features.map((f) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.gold.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(f.$1, size: 15, color: AppColors.gold.withOpacity(0.75)),
                  const SizedBox(width: 6),
                  Text(
                    f.$2,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.70),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _animatedCTA() {
    final glowOpacity = 0.18 + 0.14 * _pulseCtrl.value;
    final scale = 1.0 + 0.015 * _pulseCtrl.value;

    return Opacity(
      opacity: _ctaOpacity.value,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - _ctaOpacity.value)),
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withOpacity(glowOpacity),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: GradientButton(
              text: 'Keşfetmeye Başla',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: _goToHome,
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedHint() {
    return Opacity(
      opacity: _ctaOpacity.value * 0.5,
      child: Text(
        'Ekrana dokunarak yıldız oluştur ✦',
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withOpacity(0.35),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TapRipple {
  final Offset position;
  final AnimationController controller;
  const _TapRipple({required this.position, required this.controller});
}

class _LandingBgPainter extends CustomPainter {
  final double time;
  final List<_TapRipple> ripples;

  _LandingBgPainter({required this.time, required this.ripples});

  @override
  void paint(Canvas canvas, Size size) {
    _drawNebula(canvas, size);
    _drawStars(canvas, size);
    _drawConstellations(canvas, size);
    _drawShootingStars(canvas, size);
    _drawRipples(canvas, size);
  }

  void _drawNebula(Canvas canvas, Size size) {
    final orbs = [
      (0.25, 0.20, 0.18, const Color(0xFF4A2070), 0.06),
      (0.75, 0.55, 0.22, const Color(0xFF1A1A5E), 0.05),
      (0.50, 0.80, 0.15, const Color(0xFF6DD5FA), 0.025),
      (0.15, 0.65, 0.12, const Color(0xFFE040A0), 0.03),
    ];
    for (final orb in orbs) {
      final phase = orb.$1 + orb.$2;
      final dx = orb.$1 * size.width +
          math.sin(time * math.pi * 2 * 0.5 + phase * 8) * 20;
      final dy = orb.$2 * size.height +
          math.cos(time * math.pi * 2 * 0.3 + phase * 6) * 16;
      final r = orb.$3 * size.width;
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(dx, dy),
          r,
          [orb.$4.withOpacity(orb.$5 as double), orb.$4.withOpacity(0.0)],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final rnd = math.Random(77);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 220; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final phase = (i * 0.07) % 1.0;
      final twinkle = 0.5 + 0.5 * math.sin((time + phase) * math.pi * 2);
      final baseAlpha = 0.15 + 0.35 * rnd.nextDouble();
      final opacity = (baseAlpha * (0.4 + 0.6 * twinkle)).clamp(0.0, 1.0);
      final r = 0.4 + rnd.nextDouble() * 2.2;

      Color color;
      if (i % 22 == 0) {
        color = AppColors.gold.withOpacity(opacity);
      } else if (i % 33 == 0) {
        color = AppColors.aiAccent.withOpacity(opacity * 0.75);
      } else {
        color = Colors.white.withOpacity(opacity);
      }

      paint.color = color;
      paint.maskFilter = null;
      canvas.drawCircle(Offset(x, y), r, paint);

      if (r > 1.6) {
        paint.color = color.withOpacity(opacity * 0.12);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(Offset(x, y), r * 3.5, paint);
        paint.maskFilter = null;
      }
    }
  }

  void _drawConstellations(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final pts = <Offset>[];
    for (int i = 0; i < 14; i++) {
      pts.add(Offset(
        size.width * 0.08 + rnd.nextDouble() * size.width * 0.84,
        size.height * 0.04 + rnd.nextDouble() * size.height * 0.38,
      ));
    }

    final pulse = 0.5 + 0.5 * math.sin(time * math.pi * 2);
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.035 + 0.02 * pulse)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < pts.length - 1; i++) {
      if ((pts[i] - pts[i + 1]).distance < size.width * 0.22) {
        canvas.drawLine(pts[i], pts[i + 1], linePaint);
      }
    }
    for (int i = 0; i < pts.length - 2; i += 2) {
      if ((pts[i] - pts[i + 2]).distance < size.width * 0.28) {
        canvas.drawLine(pts[i], pts[i + 2], linePaint);
      }
    }
  }

  void _drawShootingStars(Canvas canvas, Size size) {
    final rnd = math.Random(55);
    for (int i = 0; i < 7; i++) {
      final speed = 0.7 + rnd.nextDouble() * 0.6;
      final phase = (time * speed + i * 0.143) % 1.0;
      if (phase > 0.10) continue;

      final progress = phase / 0.10;
      final startX = rnd.nextDouble() * size.width * 0.7;
      final startY = rnd.nextDouble() * size.height * 0.45;
      final angle = 0.25 + rnd.nextDouble() * 0.45;
      final len = 90 + rnd.nextDouble() * 130;

      final cx = startX + math.cos(angle) * len * progress;
      final cy = startY + math.sin(angle) * len * progress;
      final tailLen = 55 * (1 - progress * 0.4);
      final tx = cx - math.cos(angle) * tailLen;
      final ty = cy - math.sin(angle) * tailLen;
      final op = (0.55 * (1 - progress)).clamp(0.0, 1.0);

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(tx, ty),
          Offset(cx, cy),
          [Colors.transparent, Colors.white.withOpacity(op)],
        )
        ..strokeWidth = 1.5 + (1 - progress) * 0.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(tx, ty), Offset(cx, cy), paint);

      final glow = Paint()
        ..color = Colors.white.withOpacity(op * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(cx, cy), 2, glow);
    }
  }

  void _drawRipples(Canvas canvas, Size size) {
    for (final ripple in ripples) {
      final v = ripple.controller.value;
      final radius = v * 130;
      final op = (1 - v) * 0.45;

      final ringPaint = Paint()
        ..color = AppColors.gold.withOpacity(op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - v);
      canvas.drawCircle(ripple.position, radius, ringPaint);

      if (v < 0.4) {
        final inner = Paint()
          ..color = AppColors.gold.withOpacity((1 - v * 2.5) * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(ripple.position, radius * 0.4, inner);
      }

      final sparkRnd = math.Random(ripple.position.dx.toInt());
      for (int s = 0; s < 6; s++) {
        final sparkAngle = sparkRnd.nextDouble() * math.pi * 2;
        final sparkDist = radius * (0.6 + sparkRnd.nextDouble() * 0.4);
        final sparkX = ripple.position.dx + math.cos(sparkAngle) * sparkDist;
        final sparkY = ripple.position.dy + math.sin(sparkAngle) * sparkDist;
        final sparkOp = op * 0.6 * (1 - v);
        final sparkPaint = Paint()
          ..color = AppColors.gold.withOpacity(sparkOp.clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(sparkX, sparkY), 1.5 * (1 - v), sparkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LandingBgPainter old) => true;
}
