import 'package:flutter/foundation.dart';

import '../models/track.dart';

enum MixPhase { off, preparing, mixing }

enum AutomixProfile { smooth, club }


@immutable
class PlaybackState {

  final List<Track> queue;
  final int? currentIndex;

  final bool isPlaying;
  final bool shuffleEnabled;

  /// 0 = off, 1 = repeat-one, 2 = repeat-all
  final int repeatMode;

  final Duration position;

  /// Duration reported by the audio engine for the current item.
  ///
  /// This is used because metadata duration might be missing.
  final Duration? currentDuration;

  // --- Automix ---

  final bool automixEnabled;

  /// Updated automatically per transition (DJ-style, bar-aligned).
  ///
  /// Kept in state so UI can show the planned mix length.
  final Duration automixCrossfade;

  /// How early we pre-load the next track.
  final Duration automixPreRoll;

  final AutomixProfile automixProfile;
  final bool automixBeatmatch;
  final bool automixEq;

  /// Allowed tempo change during beatmatch (0.06 = ±6%).
  final double automixMaxTempoDelta;


  /// UI/automation state for the currently planned transition.
  final MixPhase mixPhase;

  /// 0..1 crossfade progress during [MixPhase.mixing].
  final double mixProgress01;

  /// Last playback error (best-effort; shown to user).
  final String? lastError;


  static const Object _noChange = Object();

  const PlaybackState({
    required this.queue,
    required this.currentIndex,
    required this.isPlaying,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.position,
    required this.currentDuration,
    required this.automixEnabled,
    required this.automixCrossfade,
    required this.automixPreRoll,
    required this.automixProfile,
    required this.automixBeatmatch,
    required this.automixEq,
    required this.automixMaxTempoDelta,
    required this.mixPhase,
    required this.mixProgress01,
    required this.lastError,
  });

  const PlaybackState.initial()
      : queue = const [],
        currentIndex = null,
        isPlaying = false,
        shuffleEnabled = false,
        repeatMode = 0,
        position = Duration.zero,
        currentDuration = null,
        automixEnabled = false,
        automixCrossfade = const Duration(seconds: 8),
        automixPreRoll = const Duration(seconds: 8),
        automixProfile = AutomixProfile.smooth,
        automixBeatmatch = true,
        automixEq = true,
        automixMaxTempoDelta = 0.06,
        mixPhase = MixPhase.off,
        mixProgress01 = 0.0,
        lastError = null;


  bool get hasQueue => queue.isNotEmpty;
  bool get hasTrack => currentTrack != null;

  Track? get currentTrack {
    final index = currentIndex;
    if (index == null) return null;
    if (index < 0 || index >= queue.length) return null;
    return queue[index];
  }

  Duration? get duration => currentDuration ?? currentTrack?.duration;

  double get progress01 {
    final d = duration;
    if (d == null || d.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? shuffleEnabled,
    int? repeatMode,
    Duration? position,
    Duration? currentDuration,
    bool? automixEnabled,
    Duration? automixCrossfade,
    Duration? automixPreRoll,
    AutomixProfile? automixProfile,
    bool? automixBeatmatch,
    bool? automixEq,
    double? automixMaxTempoDelta,
    MixPhase? mixPhase,
    double? mixProgress01,
    Object? lastError = _noChange,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      position: position ?? this.position,
      currentDuration: currentDuration ?? this.currentDuration,
      automixEnabled: automixEnabled ?? this.automixEnabled,
      automixCrossfade: automixCrossfade ?? this.automixCrossfade,
      automixPreRoll: automixPreRoll ?? this.automixPreRoll,
      automixProfile: automixProfile ?? this.automixProfile,
      automixBeatmatch: automixBeatmatch ?? this.automixBeatmatch,
      automixEq: automixEq ?? this.automixEq,
      automixMaxTempoDelta: automixMaxTempoDelta ?? this.automixMaxTempoDelta,
      mixPhase: mixPhase ?? this.mixPhase,
      mixProgress01: mixProgress01 ?? this.mixProgress01,
      lastError: identical(lastError, _noChange) ? this.lastError : lastError as String?,
    );
  }


  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PlaybackState &&
            listEquals(other.queue, queue) &&
            other.currentIndex == currentIndex &&
            other.isPlaying == isPlaying &&
            other.shuffleEnabled == shuffleEnabled &&
             other.repeatMode == repeatMode &&
             other.position == position &&
             other.currentDuration == currentDuration &&
              other.automixEnabled == automixEnabled &&
              other.automixCrossfade == automixCrossfade &&
              other.automixPreRoll == automixPreRoll &&
              other.automixProfile == automixProfile &&
              other.automixBeatmatch == automixBeatmatch &&
              other.automixEq == automixEq &&
              other.automixMaxTempoDelta == automixMaxTempoDelta &&
              other.mixPhase == mixPhase &&
              other.mixProgress01 == mixProgress01 &&
              other.lastError == lastError);


  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(queue),
        currentIndex,
        isPlaying,
        shuffleEnabled,
        repeatMode,
        position,
         currentDuration,
          automixEnabled,
          automixCrossfade,
          automixPreRoll,
          automixProfile,
          automixBeatmatch,
          automixEq,
          automixMaxTempoDelta,
          mixPhase,
          mixProgress01,
          lastError,
        );

}
