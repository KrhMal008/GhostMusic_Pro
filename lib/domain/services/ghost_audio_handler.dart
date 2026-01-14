import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// A singleton bridge between audio_service and PlaybackController.
///
/// On iOS, this enables:
/// - Now Playing in Control Center / Lock Screen
/// - Dynamic Island display (on compatible devices)
/// - Remote control (headphones, Control Center buttons)
/// - Background audio
///
/// On Windows, this is a no-op wrapper; actual playback uses MediaKit/just_audio directly.
class GhostAudioHandler extends BaseAudioHandler with SeekHandler {
  static GhostAudioHandler? _instance;
  static bool _initialized = false;

  /// Callbacks to delegate remote commands back to PlaybackController.
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;
  void Function(Duration)? onSeek;
  VoidCallback? onStop;

  GhostAudioHandler._();

  /// Initialize audio_service. Call this early in main().
  /// Returns the handler instance, or null on unsupported platforms.
  static Future<GhostAudioHandler?> init() async {
    if (_initialized) return _instance;
    _initialized = true;

    // Only initialize on iOS (and Android if needed later).
    // Windows uses MediaKit directly without audio_service.
    if (!Platform.isIOS && !Platform.isAndroid) {
      debugPrint('GhostAudioHandler: Skipping init on ${Platform.operatingSystem}');
      return null;
    }

    try {
      _instance = await AudioService.init<GhostAudioHandler>(
        builder: () => GhostAudioHandler._(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.ghostmusic.audio',
          androidNotificationChannelName: 'Ghost Music',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          // iOS specific
          // Note: artUri works automatically from MediaItem
        ),
      );
      debugPrint('GhostAudioHandler: Initialized successfully');
      return _instance;
    } catch (e) {
      debugPrint('GhostAudioHandler: Init failed: $e');
      return null;
    }
  }

  /// Get the singleton instance. May be null if not initialized or on unsupported platform.
  static GhostAudioHandler? get instance => _instance;

  /// Update the Now Playing info with current track metadata.
  void updateNowPlaying({
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
    String? trackId,
  }) {
    final item = MediaItem(
      id: trackId ?? title.hashCode.toString(),
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );

    mediaItem.add(item);
  }

  /// Update playback state (playing, paused, position, etc.)
  void updatePlaybackState({
    required bool playing,
    required Duration position,
    Duration? bufferedPosition,
    double speed = 1.0,
    AudioProcessingState processingState = AudioProcessingState.ready,
  }) {
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: bufferedPosition ?? position,
      speed: speed,
    ));
  }

  /// Mark playback as stopped/idle.
  void updateStopped() {
    playbackState.add(PlaybackState(
      controls: [],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    mediaItem.add(null);
  }

  // --- Remote command handlers (delegated to PlaybackController) ---

  @override
  Future<void> play() async {
    onPlay?.call();
  }

  @override
  Future<void> pause() async {
    onPause?.call();
  }

  @override
  Future<void> stop() async {
    onStop?.call();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    onSkipToNext?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    onSkipToPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) async {
    onSeek?.call(position);
  }

  @override
  Future<void> fastForward() async {
    // Seek forward 15 seconds (iOS standard)
    final current = playbackState.value.position;
    final duration = mediaItem.value?.duration;
    if (duration == null) return;
    
    final newPosition = current + const Duration(seconds: 15);
    if (newPosition < duration) {
      onSeek?.call(newPosition);
    } else {
      onSeek?.call(duration);
    }
  }

  @override
  Future<void> rewind() async {
    // Seek backward 15 seconds (iOS standard)
    final current = playbackState.value.position;
    final newPosition = current - const Duration(seconds: 15);
    onSeek?.call(newPosition.isNegative ? Duration.zero : newPosition);
  }
}
