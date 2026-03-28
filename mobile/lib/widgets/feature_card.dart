import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class FeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showAiBadge;
  final Duration animationDelay;

  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.showAiBadge = true,
    this.animationDelay = Duration.zero,
  });

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late AnimationController _entranceCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(widget.animationDelay, () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceCtrl,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_entranceCtrl.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - v)),
            child: child,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (context, _) {
          return GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.965 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              child: _buildCard(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard() {
    return CustomPaint(
      painter: _ShimmerBorderPainter(
        progress: _shimmerCtrl.value,
        borderRadius: 24,
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.55),
              AppColors.deepPurple.withOpacity(0.65),
              Colors.black.withOpacity(0.55),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(_pressed ? 0.12 : 0.05),
              blurRadius: _pressed ? 24 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gold, AppColors.goldSoft],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.black, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (widget.showAiBadge) ...[
                        const SizedBox(width: 8),
                        const _AiBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.gold.withOpacity(0.55),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.aiAccent.withOpacity(0.22),
            AppColors.aiAccent.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.aiAccent.withOpacity(0.40),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 10, color: AppColors.aiAccent),
          const SizedBox(width: 3),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.aiAccent,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBorderPainter extends CustomPainter {
  final double progress;
  final double borderRadius;

  _ShimmerBorderPainter({required this.progress, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: [
          AppColors.gold.withOpacity(0.04),
          AppColors.gold.withOpacity(0.45),
          AppColors.gold.withOpacity(0.04),
          AppColors.gold.withOpacity(0.02),
        ],
        stops: const [0.0, 0.15, 0.30, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerBorderPainter old) =>
      old.progress != progress;
}
