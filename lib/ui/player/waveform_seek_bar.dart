import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A waveform-based seek bar widget that displays audio amplitudes
/// and allows seeking by tap/drag.
///
/// The waveform shows played vs unplayed portions with opacity difference.
class WaveformSeekBar extends StatefulWidget {
  /// Progress value from 0.0 to 1.0
  final double progress;

  /// Current playback position
  final Duration position;

  /// Total duration (null if unknown)
  final Duration? duration;

  /// Whether user is currently dragging
  final bool isDragging;

  /// Drag value override when dragging (0.0 to 1.0)
  final double dragValue;

  /// Called when drag starts
  final ValueChanged<double> onDragStart;

  /// Called during drag
  final ValueChanged<double> onDragUpdate;

  /// Called when drag ends
  final ValueChanged<double> onDragEnd;

  /// Optional: pre-computed waveform amplitudes (0.0 to 1.0)
  /// If null, generates a deterministic pseudo-waveform
  final List<double>? amplitudes;

  /// Seed for pseudo-waveform generation (use track hashCode)
  final int waveformSeed;

  /// Height of the waveform area
  final double height;

  /// Color for played portion
  final Color playedColor;

  /// Color for unplayed portion
  final Color unplayedColor;

  const WaveformSeekBar({
    super.key,
    required this.progress,
    required this.position,
    required this.duration,
    required this.isDragging,
    required this.dragValue,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.amplitudes,
    this.waveformSeed = 0,
    this.height = 64,
    this.playedColor = Colors.white,
    this.unplayedColor = Colors.white24,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  List<double>? _cachedAmplitudes;
  int? _cachedSeed;
  int? _cachedBarCount;

  List<double> _getAmplitudes(int barCount) {
    if (widget.amplitudes != null) return widget.amplitudes!;

    // Use cached if seed matches
    if (_cachedAmplitudes != null &&
        _cachedSeed == widget.waveformSeed &&
        _cachedBarCount == barCount) {
      return _cachedAmplitudes!;
    }

    // Generate deterministic pseudo-waveform
    _cachedAmplitudes = _generatePseudoWaveform(widget.waveformSeed, barCount);
    _cachedSeed = widget.waveformSeed;
    _cachedBarCount = barCount;
    return _cachedAmplitudes!;
  }

  /// Generates a realistic-looking waveform from a seed
  static List<double> _generatePseudoWaveform(int seed, int count) {
    final rnd = math.Random(seed);
    final result = <double>[];

    // Generate with some "musicality" - clusters of similar values
    double base = 0.4 + rnd.nextDouble() * 0.3;
    int clusterLen = 3 + rnd.nextInt(5);
    int clusterIdx = 0;

    for (var i = 0; i < count; i++) {
      if (clusterIdx >= clusterLen) {
        // Start new cluster
        base = 0.25 + rnd.nextDouble() * 0.5;
        clusterLen = 2 + rnd.nextInt(6);
        clusterIdx = 0;
      }

      // Add variation within cluster
      final variation = (rnd.nextDouble() - 0.5) * 0.35;
      final amp = (base + variation).clamp(0.15, 1.0);
      result.add(amp);
      clusterIdx++;
    }

    return result;
  }

  void _handleTapOrDrag(Offset localPosition, double width) {
    if (widget.duration == null) return;

    final progress = (localPosition.dx / width).clamp(0.0, 1.0);
    widget.onDragUpdate(progress);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = widget.isDragging ? widget.dragValue : widget.progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Calculate bar count based on width (approx 3-4 pixels per bar)
        final barCount = (width / 3.5).round().clamp(30, 150);
        final amplitudes = _getAmplitudes(barCount);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            if (widget.duration == null) return;
            HapticFeedback.selectionClick();
            final progress = (details.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onDragStart(progress);
          },
          onHorizontalDragStart: (details) {
            if (widget.duration == null) return;
            HapticFeedback.selectionClick();
            final progress = (details.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onDragStart(progress);
          },
          onHorizontalDragUpdate: (details) {
            _handleTapOrDrag(details.localPosition, width);
          },
          onHorizontalDragEnd: (details) {
            final progress = widget.dragValue;
            HapticFeedback.lightImpact();
            widget.onDragEnd(progress);
          },
          onTapUp: (details) {
            final progress = (details.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onDragEnd(progress);
          },
          child: SizedBox(
            height: widget.height,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WaveformPainter(
                  amplitudes: amplitudes,
                  progress: effectiveProgress,
                  playedColor: widget.playedColor,
                  unplayedColor: widget.unplayedColor,
                ),
                size: Size(width, widget.height),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final barCount = amplitudes.length;
    final barSpacing = 2.0;
    final totalSpacing = barSpacing * (barCount - 1);
    final barWidth = (size.width - totalSpacing) / barCount;
    final minBarHeight = 4.0;
    final maxBarHeight = size.height * 0.85;
    final centerY = size.height / 2;

    final playedPaint = Paint()
      ..color = playedColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final unplayedPaint = Paint()
      ..color = unplayedColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    final progressX = size.width * progress;

    for (var i = 0; i < barCount; i++) {
      final amp = amplitudes[i].clamp(0.0, 1.0);
      final barHeight = lerpDouble(minBarHeight, maxBarHeight, amp)!;
      final x = i * (barWidth + barSpacing);
      final barCenterX = x + barWidth / 2;

      // Determine if this bar is played or unplayed
      final isPlayed = barCenterX <= progressX;
      final paint = isPlayed ? playedPaint : unplayedPaint;

      // Draw rounded bar centered vertically
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(barCenterX, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor ||
        oldDelegate.amplitudes != amplitudes;
  }
}

/// Formats a duration as MM:SS or HH:MM:SS
String formatDuration(Duration d) {
  final total = d.inSeconds.abs();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  if (hours > 0) return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  return '${twoDigits(minutes)}:${twoDigits(seconds)}';
}
