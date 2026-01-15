import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Poweramp-style transport controls - 5 dark circular buttons.
///
/// Layout (left to right):
/// - Fast rewind / previous category
/// - Previous track
/// - Play/Pause (largest)
/// - Next track
/// - Fast forward / next category
///
/// CRITICAL: During scrubbing, these buttons must:
/// - Fade to low opacity (0.12-0.25)
/// - Not capture any taps
/// - Allow drag gestures to pass through
class PowerampTransportControls extends StatelessWidget {
  final bool isPlaying;
  final bool isScrubbing;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFastRewind;
  final VoidCallback onFastForward;
  final ValueChanged<bool>? onPreviousHoldChange;
  final ValueChanged<bool>? onNextHoldChange;

  const PowerampTransportControls({
    super.key,
    required this.isPlaying,
    required this.isScrubbing,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onFastRewind,
    required this.onFastForward,
    this.onPreviousHoldChange,
    this.onNextHoldChange,
  });

  @override
  Widget build(BuildContext context) {
    // During scrubbing, buttons fade and become non-interactive
    final opacity = isScrubbing ? 0.18 : 1.0;

    return IgnorePointer(
      ignoring: isScrubbing,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fast rewind / category skip
            _TransportButton(
              icon: Icons.fast_rewind_rounded,
              size: 48,
              iconSize: 24,
              onTap: onFastRewind,
              onLongPressStart: () => onPreviousHoldChange?.call(true),
              onLongPressEnd: () => onPreviousHoldChange?.call(false),
            ),

            const SizedBox(width: 8),

            // Previous track
            _TransportButton(
              icon: Icons.skip_previous_rounded,
              size: 56,
              iconSize: 30,
              onTap: onPrevious,
              onLongPressStart: () => onPreviousHoldChange?.call(true),
              onLongPressEnd: () => onPreviousHoldChange?.call(false),
            ),

            const SizedBox(width: 14),

            // Play/Pause (largest)
            _PlayPauseButton(
              isPlaying: isPlaying,
              onPressed: onPlayPause,
            ),

            const SizedBox(width: 14),

            // Next track
            _TransportButton(
              icon: Icons.skip_next_rounded,
              size: 56,
              iconSize: 30,
              onTap: onNext,
              onLongPressStart: () => onNextHoldChange?.call(true),
              onLongPressEnd: () => onNextHoldChange?.call(false),
            ),

            const SizedBox(width: 8),

            // Fast forward / category skip
            _TransportButton(
              icon: Icons.fast_forward_rounded,
              size: 48,
              iconSize: 24,
              onTap: onFastForward,
              onLongPressStart: () => onNextHoldChange?.call(true),
              onLongPressEnd: () => onNextHoldChange?.call(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const _TransportButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {
  bool _pressed = false;
  bool _longPressing = false;
  Timer? _longPressTimer;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _pressed = true);

    // Start long press detection
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 300), () {
      if (_pressed && mounted) {
        setState(() => _longPressing = true);
        HapticFeedback.mediumImpact();
        widget.onLongPressStart?.call();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _longPressTimer?.cancel();

    if (_longPressing) {
      widget.onLongPressEnd?.call();
    } else {
      HapticFeedback.lightImpact();
      widget.onTap();
    }

    setState(() {
      _pressed = false;
      _longPressing = false;
    });
  }

  void _handleTapCancel() {
    _longPressTimer?.cancel();

    if (_longPressing) {
      widget.onLongPressEnd?.call();
    }

    setState(() {
      _pressed = false;
      _longPressing = false;
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.90),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
