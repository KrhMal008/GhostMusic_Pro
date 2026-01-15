import 'dart:async';

import 'package:flutter/foundation.dart';

/// Sleep timer durations available
enum SleepTimerDuration {
  off(0, 'Off'),
  min5(5, '5 min'),
  min10(10, '10 min'),
  min15(15, '15 min'),
  min30(30, '30 min'),
  min45(45, '45 min'),
  min60(60, '60 min'),
  endOfTrack(-1, 'End of track');

  final int minutes;
  final String label;

  const SleepTimerDuration(this.minutes, this.label);
}

/// Controller for sleep timer functionality.
///
/// Features:
/// - Multiple preset durations
/// - "End of track" option
/// - Pause/stop playback when timer fires
/// - Persist state across screen rebuilds
class SleepTimerController extends ChangeNotifier {
  SleepTimerController({required this.onTimerFired});

  /// Callback when timer fires (should pause/stop playback)
  final VoidCallback onTimerFired;

  SleepTimerDuration _selectedDuration = SleepTimerDuration.off;
  SleepTimerDuration get selectedDuration => _selectedDuration;

  Timer? _timer;
  DateTime? _endTime;
  Duration _remaining = Duration.zero;

  bool get isActive => _selectedDuration != SleepTimerDuration.off && _endTime != null;
  bool get isEndOfTrack => _selectedDuration == SleepTimerDuration.endOfTrack;

  Duration get remaining => _remaining;

  String get remainingFormatted {
    if (!isActive) return '';
    if (isEndOfTrack) return 'End of track';

    final mins = _remaining.inMinutes;
    final secs = _remaining.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Set the sleep timer duration
  void setDuration(SleepTimerDuration duration) {
    _cancelTimer();

    _selectedDuration = duration;

    if (duration == SleepTimerDuration.off) {
      _endTime = null;
      _remaining = Duration.zero;
    } else if (duration == SleepTimerDuration.endOfTrack) {
      // Special case: fires at end of current track
      _endTime = null; // Handled by track completion callback
      _remaining = Duration.zero;
    } else {
      // Start countdown timer
      _endTime = DateTime.now().add(Duration(minutes: duration.minutes));
      _remaining = Duration(minutes: duration.minutes);
      _startCountdown();
    }

    notifyListeners();
  }

  /// Called when track ends (for "end of track" mode)
  void onTrackEnded() {
    if (_selectedDuration == SleepTimerDuration.endOfTrack) {
      _fireTimer();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (_endTime == null) return;

    final now = DateTime.now();
    if (now.isAfter(_endTime!)) {
      _fireTimer();
      return;
    }

    _remaining = _endTime!.difference(now);
    notifyListeners();
  }

  void _fireTimer() {
    _cancelTimer();
    _selectedDuration = SleepTimerDuration.off;
    _endTime = null;
    _remaining = Duration.zero;

    onTimerFired();
    notifyListeners();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancel the active timer
  void cancel() {
    setDuration(SleepTimerDuration.off);
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }
}
