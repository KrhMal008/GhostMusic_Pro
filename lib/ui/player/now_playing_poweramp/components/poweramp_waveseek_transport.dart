import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ghostmusic/domain/state/playback_state.dart';
import '../state/scrub_controller.dart';

/// Combined WaveSeek surface with Transport controls overlay.
///
/// CRITICAL GESTURE BEHAVIOR:
/// - The waveseek surface MUST capture ALL horizontal drags
/// - Transport buttons fade (opacity 0.15) and become non-interactive during scrub
/// - Buttons use IgnorePointer during scrub to allow drag to pass through
///
/// TRANSPORT BUTTON BEHAVIOR (per spec):
/// - Far left (fast_rewind): Tap = previous track, Long-press = NOTHING
/// - Inner left (skip_previous): Tap = previous track, Long-press = continuous rewind
/// - Center (play/pause): Tap = toggle
/// - Inner right (skip_next): Tap = next track, Long-press = continuous fast-forward
/// - Far right (fast_forward): Tap = next track, Long-press = NOTHING
class PowerampWaveseekTransport extends StatefulWidget {
  final PlaybackState state;
  final ScrubController scrubController;
  final int trackId;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final ValueChanged<bool> onInnerPreviousHoldChange;
  final ValueChanged<bool> onInnerNextHoldChange;

  const PowerampWaveseekTransport({
    super.key,
    required this.state,
    required this.scrubController,
    required this.trackId,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onInnerPreviousHoldChange,
    required this.onInnerNextHoldChange,
  });

  @override
  State<PowerampWaveseekTransport> createState() => _PowerampWaveseekTransportState();
}

class _PowerampWaveseekTransportState extends State<PowerampWaveseekTransport>
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
  void didUpdateWidget(covariant PowerampWaveseekTransport oldWidget) {
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
    widget.scrubController.tick(1 / 60);
  }

  void _onScrubChange() {
    setState(() {});
  }

  void _generateWaveform() {
    if (_cachedTrackId == widget.trackId && _waveformData != null) return;
    _waveformData = _generatePseudoWaveform(widget.trackId, 100);
    _cachedTrackId = widget.trackId;
  }

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
    final isScrubbing = widget.scrubController.isScrubbing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Waveform visualization (background)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: widget.scrubController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _WaveseekPainter(
                        amplitudes: _waveformData ?? [],
                        progress: widget.scrubController.visualProgress,
                        isScrubbing: isScrubbing,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),
            ),

            // Transport controls (fade during scrub)
            AnimatedOpacity(
              opacity: isScrubbing ? 0.15 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: isScrubbing,
                child: _TransportButtons(
                  isPlaying: widget.state.isPlaying,
                  onPrevious: widget.onPrevious,
                  onNext: widget.onNext,
                  onPlayPause: widget.onPlayPause,
                  onInnerPreviousHoldChange: widget.onInnerPreviousHoldChange,
                  onInnerNextHoldChange: widget.onInnerNextHoldChange,
                ),
              ),
            ),

            // Gesture layer (MUST be on top to capture all horizontal drags)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onPanStart,
                onHorizontalDragUpdate: _onPanUpdate,
                onHorizontalDragEnd: _onPanEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transport buttons row
class _TransportButtons extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final ValueChanged<bool> onInnerPreviousHoldChange;
  final ValueChanged<bool> onInnerNextHoldChange;

  const _TransportButtons({
    required this.isPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onInnerPreviousHoldChange,
    required this.onInnerNextHoldChange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Far left: fast_rewind - Tap = previous, NO long-press
        _OuterTransportButton(
          icon: Icons.fast_rewind_rounded,
          size: 48,
          iconSize: 24,
          onTap: onPrevious,
          // NO long-press handler - this is intentional per spec
        ),

        const SizedBox(width: 8),

        // Inner left: skip_previous - Tap = previous, Long-press = continuous rewind
        _InnerTransportButton(
          icon: Icons.skip_previous_rounded,
          size: 56,
          iconSize: 30,
          onTap: onPrevious,
          onHoldChange: onInnerPreviousHoldChange,
        ),

        const SizedBox(width: 14),

        // Center: play/pause
        _PlayPauseButton(
          isPlaying: isPlaying,
          onPressed: onPlayPause,
        ),

        const SizedBox(width: 14),

        // Inner right: skip_next - Tap = next, Long-press = continuous fast-forward
        _InnerTransportButton(
          icon: Icons.skip_next_rounded,
          size: 56,
          iconSize: 30,
          onTap: onNext,
          onHoldChange: onInnerNextHoldChange,
        ),

        const SizedBox(width: 8),

        // Far right: fast_forward - Tap = next, NO long-press
        _OuterTransportButton(
          icon: Icons.fast_forward_rounded,
          size: 48,
          iconSize: 24,
          onTap: onNext,
          // NO long-press handler - this is intentional per spec
        ),
      ],
    );
  }
}

/// Outer transport button (far left/right) - NO long-press action
class _OuterTransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _OuterTransportButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  State<_OuterTransportButton> createState() => _OuterTransportButtonState();
}

class _OuterTransportButtonState extends State<_OuterTransportButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      // NO onLongPress - outer buttons don't have continuous seek
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

/// Inner transport button (skip_previous/skip_next) - HAS long-press for continuous seek
class _InnerTransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoldChange;

  const _InnerTransportButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
    required this.onHoldChange,
  });

  @override
  State<_InnerTransportButton> createState() => _InnerTransportButtonState();
}

class _InnerTransportButtonState extends State<_InnerTransportButton> {
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
        widget.onHoldChange(true);
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    _longPressTimer?.cancel();

    if (_longPressing) {
      widget.onHoldChange(false);
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
      widget.onHoldChange(false);
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

/// Play/Pause button (center, largest)
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

/// Waveform painter
class _WaveseekPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final bool isScrubbing;

  _WaveseekPainter({
    required this.amplitudes,
    required this.progress,
    required this.isScrubbing,
  });

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
    const barSpacing = 2.5;
    final totalSpacing = barSpacing * (barCount - 1);
    final barWidth = (size.width - totalSpacing) / barCount;
    const minHeight = 4.0;
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
