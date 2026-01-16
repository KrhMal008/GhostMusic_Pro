import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/sleep_timer_controller.dart';

/// Poweramp-style utility row with icons:
/// - Queue (replaces Visualizer)
/// - Sleep Timer
/// - Repeat
/// - Shuffle
///
/// Layout: [Queue] [Sleep] ... [Repeat] [Shuffle]
class PowerampUtilityRow extends StatelessWidget {
  final bool shuffleEnabled;
  final int repeatMode; // 0=off, 1=one, 2=all
  final SleepTimerController sleepTimerController;
  final VoidCallback onShuffleTap;
  final VoidCallback onRepeatTap;
  final VoidCallback onQueueTap;
  final VoidCallback onSleepTap;
  final VoidCallback? onShuffleLongPress;
  final VoidCallback? onRepeatLongPress;

  const PowerampUtilityRow({
    super.key,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerController,
    required this.onShuffleTap,
    required this.onRepeatTap,
    required this.onQueueTap,
    required this.onSleepTap,
    this.onShuffleLongPress,
    this.onRepeatLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Queue, Sleep Timer
          Row(
            children: [
              // Queue button (replaces Visualizer)
              _UtilityButton(
                icon: Icons.queue_music_rounded,
                isActive: false,
                onTap: onQueueTap,
                tooltip: 'Queue',
              ),
              const SizedBox(width: 20),
              // Sleep Timer button
              ListenableBuilder(
                listenable: sleepTimerController,
                builder: (context, _) {
                  return _SleepTimerButton(
                    isActive: sleepTimerController.isActive,
                    remainingFormatted: sleepTimerController.remainingFormatted,
                    onTap: onSleepTap,
                  );
                },
              ),
            ],
          ),

          // Right side: Repeat, Shuffle
          Row(
            children: [
              _UtilityButton(
                icon: _repeatIcon(),
                isActive: repeatMode != 0,
                onTap: onRepeatTap,
                onLongPress: onRepeatLongPress,
                tooltip: _repeatTooltip(),
              ),
              const SizedBox(width: 20),
              _UtilityButton(
                icon: Icons.shuffle_rounded,
                isActive: shuffleEnabled,
                onTap: onShuffleTap,
                onLongPress: onShuffleLongPress,
                tooltip: 'Shuffle',
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _repeatIcon() {
    return repeatMode == 1 ? Icons.repeat_one_rounded : Icons.repeat_rounded;
  }

  String _repeatTooltip() {
    return switch (repeatMode) {
      0 => 'Repeat Off',
      1 => 'Repeat One',
      2 => 'Repeat All',
      _ => 'Repeat',
    };
  }
}

class _UtilityButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String tooltip;

  const _UtilityButton({
    required this.icon,
    required this.isActive,
    this.onTap,
    this.onLongPress,
    required this.tooltip,
  });

  @override
  State<_UtilityButton> createState() => _UtilityButtonState();
}

class _UtilityButtonState extends State<_UtilityButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? const Color(0xFF4FC3F7)
        : Colors.white.withValues(alpha: 0.55);

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress?.call();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: 44,
            height: 44,
            decoration: widget.isActive
                ? BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Icon(
              widget.icon,
              size: 22,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleep timer button with optional remaining time badge
class _SleepTimerButton extends StatefulWidget {
  final bool isActive;
  final String remainingFormatted;
  final VoidCallback onTap;

  const _SleepTimerButton({
    required this.isActive,
    required this.remainingFormatted,
    required this.onTap,
  });

  @override
  State<_SleepTimerButton> createState() => _SleepTimerButtonState();
}

class _SleepTimerButtonState extends State<_SleepTimerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? const Color(0xFF4FC3F7)
        : Colors.white.withValues(alpha: 0.55);

    return Tooltip(
      message: widget.isActive
          ? 'Sleep Timer: ${widget.remainingFormatted}'
          : 'Sleep Timer',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: widget.isActive ? 10 : 0),
            constraints: const BoxConstraints(minWidth: 44),
            decoration: widget.isActive
                ? BoxDecoration(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 22,
                  color: color,
                ),
                if (widget.isActive && widget.remainingFormatted.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.remainingFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
