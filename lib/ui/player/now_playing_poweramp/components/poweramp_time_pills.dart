import 'package:flutter/material.dart';

/// Poweramp-style time pills positioned at waveform ends.
///
/// - Left: elapsed time
/// - Right: total duration
class PowerampTimePills extends StatelessWidget {
  final Duration position;
  final Duration? duration;

  const PowerampTimePills({
    super.key,
    required this.position,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final d = duration;
    final clampedPosition = d == null
        ? position
        : Duration(milliseconds: position.inMilliseconds.clamp(0, d.inMilliseconds));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Elapsed time
          _TimePill(time: _formatDuration(clampedPosition)),

          // Total duration
          _TimePill(time: d != null ? _formatDuration(d) : '--:--'),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds.abs();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

class _TimePill extends StatelessWidget {
  final String time;

  const _TimePill({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Text(
        time,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.75),
          letterSpacing: 0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
