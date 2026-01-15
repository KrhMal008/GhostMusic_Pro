import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/sleep_timer_controller.dart';

/// Sleep timer selection sheet (Poweramp-style).
class PowerampSleepTimerSheet extends StatelessWidget {
  final SleepTimerController controller;

  const PowerampSleepTimerSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, SleepTimerController controller) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (_) => PowerampSleepTimerSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 24,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sleep Timer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  const Spacer(),
                  if (controller.isActive)
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4FC3F7).withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            controller.remainingFormatted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4FC3F7),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Duration options
            ...SleepTimerDuration.values.map((duration) {
              return _DurationOption(
                duration: duration,
                isSelected: controller.selectedDuration == duration,
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.setDuration(duration);
                  Navigator.of(context).pop();
                },
              );
            }),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DurationOption extends StatefulWidget {
  final SleepTimerDuration duration;
  final bool isSelected;
  final VoidCallback onTap;

  const _DurationOption({
    required this.duration,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DurationOption> createState() => _DurationOptionState();
}

class _DurationOptionState extends State<_DurationOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isOff = widget.duration == SleepTimerDuration.off;
    final isEndOfTrack = widget.duration == SleepTimerDuration.endOfTrack;

    IconData? icon;
    if (isOff) {
      icon = Icons.timer_off_outlined;
    } else if (isEndOfTrack) {
      icon = Icons.music_note_rounded;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFF4FC3F7).withValues(alpha: 0.15)
              : _pressed
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: widget.isSelected
                    ? const Color(0xFF4FC3F7)
                    : Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                widget.duration.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected
                      ? const Color(0xFF4FC3F7)
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            if (widget.isSelected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: Color(0xFF4FC3F7),
              ),
          ],
        ),
      ),
    );
  }
}
