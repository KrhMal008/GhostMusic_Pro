import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Poweramp-style utility row with icons: Visualizer, Sleep, Repeat, Shuffle.
///
/// Behaviors:
/// - Tap cycles through modes
/// - Long press opens mode selection menu
class PowerampUtilityRow extends StatelessWidget {
  final bool shuffleEnabled;
  final int repeatMode; // 0=off, 1=one, 2=all
  final VoidCallback onShuffleTap;
  final VoidCallback onRepeatTap;
  final VoidCallback? onShuffleLongPress;
  final VoidCallback? onRepeatLongPress;
  final VoidCallback? onVisualizerTap;
  final VoidCallback? onSleepTap;

  const PowerampUtilityRow({
    super.key,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.onShuffleTap,
    required this.onRepeatTap,
    this.onShuffleLongPress,
    this.onRepeatLongPress,
    this.onVisualizerTap,
    this.onSleepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Visualizer, Sleep
          Row(
            children: [
              _UtilityButton(
                icon: Icons.equalizer_rounded,
                isActive: false,
                onTap: onVisualizerTap,
                tooltip: 'Visualizer',
              ),
              const SizedBox(width: 20),
              _UtilityButton(
                icon: Icons.timer_outlined,
                isActive: false,
                onTap: onSleepTap,
                tooltip: 'Sleep Timer',
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
                tooltip: 'Repeat',
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
