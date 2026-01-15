import 'dart:ui';

import 'package:flutter/material.dart';

import '../state/scrub_controller.dart';

/// Poweramp-style WaveSeek surface - the primary seek interaction.
///
/// CRITICAL REQUIREMENTS:
/// - This IS the seek surface, not a progress overlay
/// - Dragging anywhere seeks the audio position
/// - Generates deterministic pseudo-waveform from track ID
/// - Supports smooth 120Hz rendering
/// - Implements knob-like haptics via ScrubController
class PowerampWaveseekSurface extends StatefulWidget {
  final ScrubController scrubController;
  final int trackId; // For deterministic waveform generation
  final double height;

  const PowerampWaveseekSurface({
    super.key,
    required this.scrubController,
    required this.trackId,
    this.height = 70,
  });

  @override
  State<PowerampWaveseekSurface> createState() => _PowerampWaveseekSurfaceState();
}

class _PowerampWaveseekSurfaceState extends State<PowerampWaveseekSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickController;
  List<double>? _waveformData;
  int? _cachedTrackId;

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickController.addListener(_onTick);
    widget.scrubController.addListener(_onScrubChange);

    _generateWaveform();
  }

  @override
  void didUpdateWidget(covariant PowerampWaveseekSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) {
      _generateWaveform();
    }
    if (oldWidget.scrubController != widget.scrubController) {
      oldWidget.scrubController.removeListener(_onScrubChange);
      widget.scrubController.addListener(_onScrubChange);
    }
  }

  @override
  void dispose() {
    _tickController.removeListener(_onTick);
    _tickController.dispose();
    widget.scrubController.removeListener(_onScrubChange);
    super.dispose();
  }

  void _onTick() {
    // Update interpolation each frame
    widget.scrubController.tick(1 / 60);
  }

  void _onScrubChange() {
    // Force repaint when scrub state changes
    setState(() {});
  }

  void _generateWaveform() {
    if (_cachedTrackId == widget.trackId && _waveformData != null) return;

    // Generate deterministic pseudo-waveform
    _waveformData = _generatePseudoWaveform(widget.trackId, 100);
    _cachedTrackId = widget.trackId;
  }

  /// Generates a realistic-looking waveform from a seed
  static List<double> _generatePseudoWaveform(int seed, int count) {
    final rnd = _SeededRandom(seed);
    final result = <double>[];

    double base = 0.4 + rnd.nextDouble() * 0.3;
    int clusterLen = 3 + rnd.nextInt(5);
    int clusterIdx = 0;

    for (var i = 0; i < count; i++) {
      if (clusterIdx >= clusterLen) {
        base = 0.25 + rnd.nextDouble() * 0.5;
        clusterLen = 2 + rnd.nextInt(6);
        clusterIdx = 0;
      }

      final variation = (rnd.nextDouble() - 0.5) * 0.35;
      final amp = (base + variation).clamp(0.15, 1.0);
      result.add(amp);
      clusterIdx++;
    }

    return result;
  }

  void _onPanStart(DragStartDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localX = details.localPosition.dx;
    final progress = (localX / box.size.width).clamp(0.0, 1.0);

    widget.scrubController.startScrub(progress);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final localX = details.localPosition.dx;
    final progress = (localX / box.size.width).clamp(0.0, 1.0);

    widget.scrubController.updateScrub(progress, details.delta.dx);
  }

  void _onPanEnd(DragEndDetails details) {
    widget.scrubController.endScrub();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: widget.scrubController,
            builder: (context, _) {
              return CustomPaint(
                painter: _WaveseekPainter(
                  amplitudes: _waveformData ?? [],
                  progress: widget.scrubController.visualProgress,
                  isScrubbing: widget.scrubController.isScrubbing,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for the waveform visualization.
///
/// Performance optimizations:
/// - Cached paints
/// - No allocations in paint()
/// - Minimal calculations per frame
class _WaveseekPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final bool isScrubbing;

  _WaveseekPainter({
    required this.amplitudes,
    required this.progress,
    required this.isScrubbing,
  });

  // Cached paints
  static final _playedPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..style = PaintingStyle.fill;

  static final _unplayedPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.35)
    ..style = PaintingStyle.fill;

  static final _scrubbingPlayedPaint = Paint()
    ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.95)
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final barCount = amplitudes.length;
    final barSpacing = 2.5;
    final totalSpacing = barSpacing * (barCount - 1);
    final barWidth = (size.width - totalSpacing) / barCount;
    final minHeight = 4.0;
    final maxHeight = size.height * 0.85;
    final centerY = size.height / 2;

    final progressX = size.width * progress;
    final playedPaint = isScrubbing ? _scrubbingPlayedPaint : _playedPaint;

    for (var i = 0; i < barCount; i++) {
      final amp = amplitudes[i].clamp(0.0, 1.0);
      final barHeight = lerpDouble(minHeight, maxHeight, amp)!;
      final x = i * (barWidth + barSpacing);
      final barCenterX = x + barWidth / 2;

      final isPlayed = barCenterX <= progressX;
      final paint = isPlayed ? playedPaint : _unplayedPaint;

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
  bool shouldRepaint(covariant _WaveseekPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isScrubbing != isScrubbing ||
        oldDelegate.amplitudes != amplitudes;
  }
}

/// Seeded random number generator for deterministic waveform
class _SeededRandom {
  int _seed;

  _SeededRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  int nextInt(int max) {
    return (nextDouble() * max).floor();
  }
}
