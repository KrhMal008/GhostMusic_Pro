import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controller for managing scrubbing state and knob-like haptics.
///
/// This is the core state machine for waveseek interactions:
/// - Tracks scrubbing state
/// - Manages haptic feedback with throttling
/// - Provides smooth position interpolation
class ScrubController extends ChangeNotifier {
  ScrubController({
    required this.onSeek,
    this.hapticsEnabled = true,
  });

  /// Callback to perform actual seek operation (throttled)
  final Future<void> Function(Duration position) onSeek;

  /// Whether haptics are enabled
  bool hapticsEnabled;

  // ─────────────────────────────────────────────────────────────────────────
  // Scrubbing State
  // ─────────────────────────────────────────────────────────────────────────

  bool _isScrubbing = false;
  bool get isScrubbing => _isScrubbing;

  /// The position being previewed during scrub (0.0 to 1.0)
  double _scrubProgress = 0.0;
  double get scrubProgress => _scrubProgress;

  /// Duration of current track for calculating positions
  Duration _trackDuration = Duration.zero;
  Duration get trackDuration => _trackDuration;

  /// The actual playback position (updated from player)
  Duration _playbackPosition = Duration.zero;
  Duration get playbackPosition => _playbackPosition;

  /// Interpolated visual position for smooth rendering
  double _visualProgress = 0.0;
  double get visualProgress => _isScrubbing ? _scrubProgress : _visualProgress;

  /// Target progress for interpolation
  double _targetProgress = 0.0;

  // ─────────────────────────────────────────────────────────────────────────
  // Haptics State
  // ─────────────────────────────────────────────────────────────────────────

  /// Accumulated drag distance for haptic triggering
  double _hapticAccumulator = 0.0;

  /// Last haptic trigger time for throttling
  DateTime _lastHapticTime = DateTime.now();

  /// Base step size in pixels for haptic ticks
  static const double _baseHapticStep = 14.0;

  /// Minimum time between haptics (ms)
  static const int _minHapticIntervalMs = 40;

  /// Last second boundary crossed (for extra tick on second boundaries)
  int _lastSecondBoundary = -1;

  // ─────────────────────────────────────────────────────────────────────────
  // Seek Throttling
  // ─────────────────────────────────────────────────────────────────────────

  Timer? _seekThrottleTimer;
  Duration? _pendingSeekPosition;
  static const int _seekThrottleMs = 50;

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Update track duration (call when track changes)
  void setTrackDuration(Duration duration) {
    _trackDuration = duration;
  }

  /// Update playback position from player (call frequently)
  void updatePlaybackPosition(Duration position) {
    _playbackPosition = position;
    if (!_isScrubbing && _trackDuration.inMilliseconds > 0) {
      _targetProgress = position.inMilliseconds / _trackDuration.inMilliseconds;
      _targetProgress = _targetProgress.clamp(0.0, 1.0);
    }
  }

  /// Called each frame to interpolate visual position smoothly
  void tick(double dt) {
    if (_isScrubbing) return;

    // Smooth interpolation towards target
    const lerp = 0.15;
    final diff = _targetProgress - _visualProgress;
    if (diff.abs() < 0.0001) {
      _visualProgress = _targetProgress;
    } else {
      _visualProgress += diff * lerp;
    }
  }

  /// Start scrubbing at the given progress (0.0 to 1.0)
  void startScrub(double progress) {
    _isScrubbing = true;
    _scrubProgress = progress.clamp(0.0, 1.0);
    _hapticAccumulator = 0.0;
    _lastHapticTime = DateTime.now();
    _lastSecondBoundary = _progressToSeconds(_scrubProgress);

    // Fire initial haptic
    _fireHaptic();

    notifyListeners();
  }

  /// Update scrub position during drag
  void updateScrub(double progress, double dragDeltaX) {
    if (!_isScrubbing) return;

    final oldProgress = _scrubProgress;
    _scrubProgress = progress.clamp(0.0, 1.0);

    // Handle haptics based on drag delta
    _processHaptics(dragDeltaX, oldProgress);

    // Throttled seek
    _throttledSeek();

    notifyListeners();
  }

  /// End scrubbing and perform final seek
  Future<void> endScrub() async {
    if (!_isScrubbing) return;

    _isScrubbing = false;
    _visualProgress = _scrubProgress;
    _targetProgress = _scrubProgress;

    // Cancel any pending throttled seek
    _seekThrottleTimer?.cancel();
    _seekThrottleTimer = null;

    // Perform final seek
    final targetPosition = Duration(
      milliseconds: (_scrubProgress * _trackDuration.inMilliseconds).round(),
    );
    await onSeek(targetPosition);

    // Final haptic
    HapticFeedback.lightImpact();

    notifyListeners();
  }

  /// Cancel scrubbing without seeking
  void cancelScrub() {
    if (!_isScrubbing) return;

    _isScrubbing = false;
    _seekThrottleTimer?.cancel();
    _seekThrottleTimer = null;
    _pendingSeekPosition = null;

    notifyListeners();
  }

  /// Get current scrub position as Duration
  Duration get scrubPosition {
    return Duration(
      milliseconds: (_scrubProgress * _trackDuration.inMilliseconds).round(),
    );
  }

  /// Get visual position as Duration (for display)
  Duration get displayPosition {
    if (_isScrubbing) {
      return scrubPosition;
    }
    return _playbackPosition;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Haptics Implementation
  // ─────────────────────────────────────────────────────────────────────────

  void _processHaptics(double dragDeltaX, double oldProgress) {
    if (!hapticsEnabled) return;

    // Accumulate drag distance
    _hapticAccumulator += dragDeltaX.abs();

    // Calculate adaptive step size based on drag speed
    // Faster drags = larger steps to avoid machine-gun haptics
    final dragSpeed = dragDeltaX.abs();
    final adaptiveStep = _baseHapticStep + (dragSpeed * 0.3).clamp(0.0, 8.0);

    // Check if we should fire a haptic based on distance
    if (_hapticAccumulator >= adaptiveStep) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastHapticTime).inMilliseconds;

      // Time-based throttling
      if (elapsed >= _minHapticIntervalMs) {
        _fireHaptic();
        _lastHapticTime = now;
        _hapticAccumulator -= adaptiveStep;
      }
    }

    // Extra tick on second boundaries
    final newSecond = _progressToSeconds(_scrubProgress);
    if (newSecond != _lastSecondBoundary) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastHapticTime).inMilliseconds;
      if (elapsed >= _minHapticIntervalMs ~/ 2) {
        _fireHaptic();
        _lastHapticTime = now;
      }
      _lastSecondBoundary = newSecond;
    }
  }

  int _progressToSeconds(double progress) {
    return (progress * _trackDuration.inSeconds).round();
  }

  void _fireHaptic() {
    if (!hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Seek Throttling Implementation
  // ─────────────────────────────────────────────────────────────────────────

  void _throttledSeek() {
    final targetPosition = Duration(
      milliseconds: (_scrubProgress * _trackDuration.inMilliseconds).round(),
    );
    _pendingSeekPosition = targetPosition;

    _seekThrottleTimer ??= Timer(
      const Duration(milliseconds: _seekThrottleMs),
      _executeThrottledSeek,
    );
  }

  void _executeThrottledSeek() {
    _seekThrottleTimer = null;
    final position = _pendingSeekPosition;
    if (position != null && _isScrubbing) {
      onSeek(position);
      _pendingSeekPosition = null;
    }
  }

  @override
  void dispose() {
    _seekThrottleTimer?.cancel();
    super.dispose();
  }
}
