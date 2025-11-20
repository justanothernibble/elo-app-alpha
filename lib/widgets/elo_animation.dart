import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/item.dart';

class EloAnimation extends StatefulWidget {
  final Item previousItem;
  final Item newItem;
  final bool showAnimation;
  final Duration duration;
  final VoidCallback? onAnimationComplete;

  const EloAnimation({
    super.key,
    required this.previousItem,
    required this.newItem,
    this.showAnimation = true,
    this.duration = const Duration(milliseconds: 500),
    this.onAnimationComplete,
  });

  @override
  State<EloAnimation> createState() => _EloAnimationState();
}

class _EloAnimationState extends State<EloAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.showAnimation) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(EloAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAnimation != oldWidget.showAnimation) {
      if (widget.showAnimation) {
        _startAnimation();
      } else {
        _controller.reset();
      }
    }
  }

  void _initializeAnimations() {
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 0.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: _getEloChangeColor(),
    ).animate(_controller);

    _controller.addListener(() {
      setState(() {});
    });
  }

  void _startAnimation() {
    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eloChange = widget.newItem.elo - widget.previousItem.elo;
    final isPositiveChange = eloChange > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _colorAnimation.value,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getEloChangeColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Icon
          if (widget.showAnimation)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + _scaleAnimation.value,
                  child: Icon(
                    isPositiveChange ? Icons.trending_up : Icons.trending_down,
                    size: 24,
                    color: _getEloChangeColor(),
                  ),
                );
              },
            ),
          if (widget.showAnimation) const SizedBox(width: 8),

          // Animated Text
          if (widget.showAnimation)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Transform.translate(
                    offset: Offset(
                      _slideAnimation.value * (isPositiveChange ? 20 : -20),
                      0,
                    ),
                    child: Text(
                      '${isPositiveChange ? '+' : ''}$eloChange',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getEloChangeColor(),
                        shadows: [
                          Shadow(
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                            color: _getEloChangeColor().withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          else
            Text(
              '${isPositiveChange ? '+' : ''}$eloChange',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getEloChangeColor(),
              ),
            ),
        ],
      ),
    );
  }

  Color _getEloChangeColor() {
    final eloChange = widget.newItem.elo - widget.previousItem.elo;
    if (eloChange > 0) {
      return Colors.green;
    } else if (eloChange < 0) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}

// Standalone widget for just showing the animation
class EloChangeIndicator extends StatelessWidget {
  final int eloChange;
  final bool showAnimation;
  final Duration duration;

  const EloChangeIndicator({
    super.key,
    required this.eloChange,
    this.showAnimation = true,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositiveChange = eloChange > 0;

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getEloChangeColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getEloChangeColor().withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositiveChange ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: _getEloChangeColor(),
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositiveChange ? '+' : ''}$eloChange',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getEloChangeColor(),
                ),
              ),
            ],
          ),
        )
        .animate()
        .slideX(
          begin: isPositiveChange ? 0.3 : -0.3,
          duration: duration,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: duration)
        .shimmer(
          duration: duration,
          color: _getEloChangeColor().withOpacity(0.3),
        );
  }

  Color _getEloChangeColor() {
    if (eloChange > 0) {
      return Colors.green.shade600;
    } else if (eloChange < 0) {
      return Colors.red.shade600;
    } else {
      return Colors.grey.shade600;
    }
  }
}
