import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SwipeDirection {
  left,
  right,
  up,
  down,
}

class GestureSurface extends StatefulWidget {
  final Widget child;

  final VoidCallback? onNext;
  final VoidCallback? onPrev;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  final double swipeThreshold;
  final double velocityThreshold;

  final bool enableHorizontalSwipe;
  final bool enableVerticalSwipe;
  final bool enableHapticFeedback;

  final bool showSwipeIndicator;
  final Color? indicatorColor;

  const GestureSurface({
    super.key,
    required this.child,
    this.onNext,
    this.onPrev,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.swipeThreshold = 50,
    this.velocityThreshold = 300,
    this.enableHorizontalSwipe = true,
    this.enableVerticalSwipe = true,
    this.enableHapticFeedback = true,
    this.showSwipeIndicator = true,
    this.indicatorColor,
  });

  @override
  State<GestureSurface> createState() => _GestureSurfaceState();
}

class _GestureSurfaceState extends State<GestureSurface>
    with SingleTickerProviderStateMixin {
  Offset _startPosition = Offset.zero;
  Offset _currentPosition = Offset.zero;
  Offset _velocity = Offset.zero;
  bool _isSwiping = false;
  SwipeDirection? _dominantDirection;
  DateTime? _lastScrollTrigger;

  late final AnimationController _indicatorController;
  late final Animation<double> _indicatorAnimation;

  static const _swipeIndicatorSize = 80.0;
  static const _swipeIndicatorOpacity = 0.25;

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _indicatorController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _startPosition = Offset.zero;
      _currentPosition = Offset.zero;
      _velocity = Offset.zero;
      _isSwiping = false;
      _dominantDirection = null;
    });
    _indicatorController.reverse();
  }

  void _onPanStart(DragStartDetails details) {
    _startPosition = details.localPosition;
    _currentPosition = details.localPosition;
    _isSwiping = true;
    _dominantDirection = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isSwiping) return;

    setState(() {
      _currentPosition = details.localPosition;
      _velocity = details.delta;
    });

    final delta = _currentPosition - _startPosition;
    final dx = delta.dx.abs();
    final dy = delta.dy.abs();

    if (_dominantDirection == null && (dx > 10 || dy > 10)) {
      if (dx > dy && widget.enableHorizontalSwipe) {
        _dominantDirection = delta.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      } else if (dy > dx && widget.enableVerticalSwipe) {
        _dominantDirection = delta.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      }

      if (_dominantDirection != null && widget.showSwipeIndicator) {
        _indicatorController.forward();
      }
    }

    if (_dominantDirection != null) {
      if (_dominantDirection == SwipeDirection.left || _dominantDirection == SwipeDirection.right) {
        _dominantDirection = delta.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      } else {
        _dominantDirection = delta.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isSwiping) {
      _reset();
      return;
    }

    final delta = _currentPosition - _startPosition;
    final velocity = details.velocity.pixelsPerSecond;
    final velocityMagnitude = velocity.distance;

    bool triggered = false;

    if (_dominantDirection != null) {
      final isHorizontal = _dominantDirection == SwipeDirection.left ||
          _dominantDirection == SwipeDirection.right;

      final distance = isHorizontal ? delta.dx.abs() : delta.dy.abs();
      final directionVelocity = isHorizontal ? velocity.dx.abs() : velocity.dy.abs();

      if (distance >= widget.swipeThreshold ||
          directionVelocity >= widget.velocityThreshold ||
          velocityMagnitude >= widget.velocityThreshold) {
        triggered = true;


        if (widget.enableHapticFeedback) {
          HapticFeedback.mediumImpact();
        }

        switch (_dominantDirection!) {
          case SwipeDirection.left:
            widget.onNext?.call();
            break;
          case SwipeDirection.right:
            widget.onPrev?.call();
            break;
          case SwipeDirection.up:
            widget.onSwipeUp?.call();
            break;
          case SwipeDirection.down:
            widget.onSwipeDown?.call();
            break;
        }
      }
    }

    if (triggered) {
      _indicatorController.reverse();
    }

    _reset();
  }


  void _onTap() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }
    widget.onTap?.call();
  }

  void _onDoubleTap() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }
    widget.onDoubleTap?.call();
  }

  void _onLongPress() {
    if (widget.enableHapticFeedback) {
      HapticFeedback.heavyImpact();
    }
    widget.onLongPress?.call();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enableVerticalSwipe) return;
    if (event is! PointerScrollEvent) return;
    if (_isSwiping) return;

    final dy = event.scrollDelta.dy;
    if (dy.abs() < 18) return;

    final now = DateTime.now();
    final last = _lastScrollTrigger;
    if (last != null && now.difference(last) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastScrollTrigger = now;

    if (widget.enableHapticFeedback) {
      HapticFeedback.selectionClick();
    }

    if (dy < 0) {
      widget.onSwipeUp?.call();
    } else {
      widget.onSwipeDown?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _reset,
        onTap: widget.onTap != null ? _onTap : null,
        onDoubleTap: widget.onDoubleTap != null ? _onDoubleTap : null,
        onLongPress: widget.onLongPress != null ? _onLongPress : null,
        child: Stack(
          children: [
            widget.child,
            if (widget.showSwipeIndicator)
              AnimatedBuilder(
                animation: _indicatorAnimation,
                builder: (context, child) {
                  if (_dominantDirection == null || _indicatorAnimation.value == 0) {
                    return const SizedBox.shrink();
                  }
                  return _buildSwipeIndicator(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.indicatorColor ?? cs.primary;

    final delta = _currentPosition - _startPosition;
    final progress = _calculateProgress(delta);

    final (icon, alignment) = switch (_dominantDirection!) {
      SwipeDirection.left => (Icons.skip_next_rounded, Alignment.centerRight),
      SwipeDirection.right => (Icons.skip_previous_rounded, Alignment.centerLeft),
      SwipeDirection.up => (Icons.queue_music_rounded, Alignment.topCenter),
      SwipeDirection.down => (Icons.keyboard_arrow_down_rounded, Alignment.bottomCenter),
    };

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Opacity(
              opacity: _indicatorAnimation.value * _swipeIndicatorOpacity * progress,
              child: Transform.scale(
                scale: 0.8 + (0.2 * progress * _indicatorAnimation.value),
                child: Container(
                  width: _swipeIndicatorSize,
                  height: _swipeIndicatorSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateProgress(Offset delta) {
    final isHorizontal = _dominantDirection == SwipeDirection.left ||
        _dominantDirection == SwipeDirection.right;

    final distance = isHorizontal ? delta.dx.abs() : delta.dy.abs();
    final maxDistance = math.max(widget.swipeThreshold * 2, 1);
    final base = (distance / maxDistance).clamp(0.0, 1.0);

    // Give a slight boost when the swipe is fast.
    final velocityNorm = (_velocity.distance / math.max(widget.velocityThreshold, 1)).clamp(0.0, 1.0);
    return math.min(1.0, base + (0.15 * velocityNorm));
  }

}

class SwipeDetector extends StatefulWidget {
  final Widget child;
  final void Function(SwipeDirection direction)? onSwipe;
  final double threshold;
  final double velocityThreshold;

  const SwipeDetector({
    super.key,
    required this.child,
    this.onSwipe,
    this.threshold = 50,
    this.velocityThreshold = 300,
  });

  @override
  State<SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<SwipeDetector> {
  Offset _startPosition = Offset.zero;
  Offset _currentPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _startPosition = details.localPosition;
        _currentPosition = details.localPosition;
      },
      onPanUpdate: (details) => _currentPosition = details.localPosition,
      onPanEnd: (details) {
        final delta = _currentPosition - _startPosition;
        final velocity = details.velocity.pixelsPerSecond;

        SwipeDirection? direction;

        if (delta.dx.abs() > delta.dy.abs()) {
          if (delta.dx.abs() >= widget.threshold ||
              velocity.dx.abs() >= widget.velocityThreshold) {
            direction = delta.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
          }
        } else {
          if (delta.dy.abs() >= widget.threshold ||
              velocity.dy.abs() >= widget.velocityThreshold) {
            direction = delta.dy > 0 ? SwipeDirection.down : SwipeDirection.up;
          }
        }

        if (direction != null) {
          widget.onSwipe?.call(direction);
        }
      },
      child: widget.child,
    );
  }
}

class DragProgressIndicator extends StatelessWidget {
  final double progress;
  final SwipeDirection direction;
  final Color? color;
  final double size;

  const DragProgressIndicator({
    super.key,
    required this.progress,
    required this.direction,
    this.color,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;

    final icon = switch (direction) {
      SwipeDirection.left => Icons.skip_next_rounded,
      SwipeDirection.right => Icons.skip_previous_rounded,
      SwipeDirection.up => Icons.expand_less_rounded,
      SwipeDirection.down => Icons.expand_more_rounded,
    };

    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.7 + (0.3 * progress),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: size * 0.5,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}

class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration duration;
  final bool enableHaptic;

  const TapScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptic = true,
  });

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _onTap() {
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    widget.onTap?.call();
  }

  void _onLongPress() {
    if (widget.enableHaptic) {
      HapticFeedback.heavyImpact();
    }
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap != null ? _onTap : null,
      onLongPress: widget.onLongPress != null ? _onLongPress : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double bounceScale;
  final Duration duration;

  const BouncingWidget({
    super.key,
    required this.child,
    this.onTap,
    this.bounceScale = 0.95,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: widget.bounceScale)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: widget.bounceScale, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap != null ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class DoubleTapDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;
  final Duration doubleTapTimeout;

  const DoubleTapDetector({
    super.key,
    required this.child,
    this.onSingleTap,
    this.onDoubleTap,
    this.doubleTapTimeout = const Duration(milliseconds: 300),
  });

  @override
  State<DoubleTapDetector> createState() => _DoubleTapDetectorState();
}

class _DoubleTapDetectorState extends State<DoubleTapDetector> {
  DateTime? _lastTapTime;
  int _tapCount = 0;

  void _handleTap() {
    final now = DateTime.now();

    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < widget.doubleTapTimeout) {
      _tapCount++;
      if (_tapCount == 2) {
        _tapCount = 0;
        _lastTapTime = null;
        widget.onDoubleTap?.call();
        return;
      }
    } else {
      _tapCount = 1;
    }

    _lastTapTime = now;

    Future.delayed(widget.doubleTapTimeout, () {
      if (_tapCount == 1 && _lastTapTime != null) {
        final elapsed = DateTime.now().difference(_lastTapTime!);
        if (elapsed >= widget.doubleTapTimeout) {
          _tapCount = 0;
          _lastTapTime = null;
          widget.onSingleTap?.call();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}

class HorizontalDragProgress extends StatefulWidget {
  final Widget child;
  final double width;
  final void Function(double progress)? onProgressChanged;
  final void Function(double progress)? onDragEnd;
  final double sensitivity;

  const HorizontalDragProgress({
    super.key,
    required this.child,
    required this.width,
    this.onProgressChanged,
    this.onDragEnd,
    this.sensitivity = 1.0,
  });

  @override
  State<HorizontalDragProgress> createState() => _HorizontalDragProgressState();
}

class _HorizontalDragProgressState extends State<HorizontalDragProgress> {
  double _progress = 0.0;
  double _startX = 0.0;
  double _startProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (details) {
        _startX = details.localPosition.dx;
        _startProgress = _progress;
      },
      onHorizontalDragUpdate: (details) {
        final delta = (details.localPosition.dx - _startX) * widget.sensitivity;
        final newProgress = (_startProgress + delta / widget.width).clamp(0.0, 1.0);

        if (newProgress != _progress) {
          setState(() => _progress = newProgress);
          widget.onProgressChanged?.call(_progress);
        }
      },
      onHorizontalDragEnd: (details) {
        widget.onDragEnd?.call(_progress);
      },
      child: widget.child,
    );
  }
}