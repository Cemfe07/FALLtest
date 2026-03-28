import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.trailingIcon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = false);
                  widget.onPressed?.call();
                }
              : null,
          onTapCancel: () => setState(() => _pressed = false),
          child: Semantics(
            button: true,
            enabled: enabled,
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: enabled ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.goldSoft, AppColors.gold],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold
                                      .withOpacity(_pressed ? 0.45 : 0.30),
                                  blurRadius: _pressed ? 24 : 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (enabled)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final shimmerX =
                                    (_shimmerCtrl.value * 2.2 - 0.6) * w;
                                return Transform.translate(
                                  offset: Offset(shimmerX, 0),
                                  child: Container(
                                    width: w * 0.3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.18),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        Center(child: _buildContent()),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (widget.trailingIcon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.text,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, color: Colors.black, size: 20),
        ],
      );
    }
    return Text(
      widget.text,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w900,
        fontSize: 15,
        letterSpacing: 0.3,
      ),
    );
  }
}
