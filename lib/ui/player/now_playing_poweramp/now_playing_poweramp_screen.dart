import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/domain/state/playback_state.dart';
import 'package:ghostmusic/ui/player/queue_sheet.dart';

import 'components/poweramp_artwork_pageview.dart';
import 'components/poweramp_background.dart';
import 'components/poweramp_bottom_nav.dart';
import 'components/poweramp_metadata_block.dart';
import 'components/poweramp_sleep_timer_sheet.dart';
import 'components/poweramp_tech_info.dart';
import 'components/poweramp_time_pills.dart';
import 'components/poweramp_track_menu.dart';
import 'components/poweramp_waveseek_transport.dart';
import 'components/poweramp_utility_row.dart';
import 'state/scrub_controller.dart';
import 'state/sleep_timer_controller.dart';

/// Poweramp-style Now Playing screen - complete 1:1 rewrite.
///
/// Layout (top to bottom):
/// - NO TOP BAR (dismiss via swipe-down only)
/// - Large artwork with PageView swipe + overlays
/// - Metadata (title, artist) - LEFT aligned
/// - Utility row (Queue, Sleep, Repeat, Shuffle)
/// - WaveSeek + Transport controls (combined gesture zone)
/// - Time pills
/// - Tech info line
/// - Bottom nav bar
class NowPlayingPowerampScreen extends ConsumerStatefulWidget {
  const NowPlayingPowerampScreen({super.key});

  @override
  ConsumerState<NowPlayingPowerampScreen> createState() =>
      _NowPlayingPowerampScreenState();
}

class _NowPlayingPowerampScreenState
    extends ConsumerState<NowPlayingPowerampScreen>
    with TickerProviderStateMixin {
  late final ScrubController _scrubController;
  late final SleepTimerController _sleepTimerController;
  late final AnimationController _dismissController;

  double _dragOffset = 0.0;
  int _bottomNavIndex = 0;

  // For continuous seek during long press on INNER transport buttons
  Timer? _seekTimer;

  @override
  void initState() {
    super.initState();

    _scrubController = ScrubController(
      onSeek: _performSeek,
      hapticsEnabled: true,
    );

    _sleepTimerController = SleepTimerController(
      onTimerFired: _onSleepTimerFired,
    );

    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Initialize with current track duration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(playbackControllerProvider);
      _scrubController.setTrackDuration(state.duration ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _scrubController.dispose();
    _sleepTimerController.dispose();
    _dismissController.dispose();
    _seekTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSeek(Duration position) async {
    final ctrl = ref.read(playbackControllerProvider.notifier);
    await ctrl.seek(position);
  }

  void _onSleepTimerFired() {
    // Pause playback when sleep timer fires
    final ctrl = ref.read(playbackControllerProvider.notifier);
    ctrl.togglePlayPause();
    HapticFeedback.mediumImpact();
  }

  void _close() {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
  }

  void _openQueue() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return QueueSheet(scrollController: scrollController);
        },
      ),
    );
  }

  void _openSleepTimer() {
    HapticFeedback.selectionClick();
    PowerampSleepTimerSheet.show(context, _sleepTimerController);
  }

  void _openTrackMenu(String trackPath) {
    HapticFeedback.selectionClick();
    PowerampTrackMenu.show(context, trackPath);
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    if (_scrubController.isScrubbing) return;
    // Only allow downward drag
    if (details.delta.dy <= 0 && _dragOffset == 0) return;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 300.0);
    });
  }

  void _onDismissDragEnd(DragEndDetails details) {
    if (_scrubController.isScrubbing) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset > 120 || velocity > 800) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    // Animate back
    final startOffset = _dragOffset;
    _dismissController.reset();
    _dismissController.addListener(() {
      setState(() {
        _dragOffset = startOffset * (1 - _dismissController.value);
      });
    });
    _dismissController.forward();
  }

  void _startContinuousSeek(bool backward) {
    _seekTimer?.cancel();

    _seekTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final state = ref.read(playbackControllerProvider);
      final ctrl = ref.read(playbackControllerProvider.notifier);
      final delta = backward
          ? const Duration(seconds: -2)
          : const Duration(seconds: 2);

      final newPosition = state.position + delta;
      final clampedPosition = Duration(
        milliseconds: newPosition.inMilliseconds.clamp(
          0,
          state.duration?.inMilliseconds ?? 0,
        ),
      );

      ctrl.seek(clampedPosition);
      HapticFeedback.selectionClick();
    });
  }

  void _stopContinuousSeek() {
    _seekTimer?.cancel();
    _seekTimer = null;
  }

  void _handleBottomNavTap(int index) {
    setState(() => _bottomNavIndex = index);

    switch (index) {
      case 0:
        // Library - close Now Playing
        _close();
        break;
      case 1:
        // EQ - open equalizer
        _openEqualizer();
        break;
      case 2:
        // Search - close and navigate
        _close();
        break;
      case 3:
        // Menu
        final track = ref.read(playbackControllerProvider).currentTrack;
        if (track != null) {
          _openTrackMenu(track.filePath);
        }
        break;
    }
  }

  void _openEqualizer() {
    HapticFeedback.selectionClick();
    // Import is lazy - only if needed
    _showEqualizerSheet();
  }

  void _showEqualizerSheet() {
    final size = MediaQuery.sizeOf(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) {
        // Lazy import to avoid circular dependencies
        return FutureBuilder(
          future: Future.microtask(() {
            // Dynamically load equalizer
            return const _EqualizerPlaceholder();
          }),
          builder: (context, snapshot) {
            return SizedBox(
              height: size.height * 0.92,
              child: snapshot.data ?? const Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }

  /// Get artwork path for a track at index in queue
  String? _getArtworkPathForIndex(int index) {
    final state = ref.read(playbackControllerProvider);
    if (index < 0 || index >= state.queue.length) return null;

    final track = state.queue[index];
    final artworkAsync = ref.read(trackArtworkPathProvider(track.filePath));

    return artworkAsync.maybeWhen(
      data: (path) => path,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final ctrl = ref.read(playbackControllerProvider.notifier);

    final track = state.currentTrack;
    final artworkAsync = track != null
        ? ref.watch(trackArtworkPathProvider(track.filePath))
        : const AsyncValue<String?>.data(null);

    final artworkPath = artworkAsync.maybeWhen(
      data: (path) => path,
      orElse: () => null,
    );

    final mq = MediaQuery.of(context);
    final bottomPadding = mq.padding.bottom;
    final topPadding = mq.padding.top;

    // Update scrub controller with current state
    _scrubController.setTrackDuration(state.duration ?? Duration.zero);
    _scrubController.updatePlaybackPosition(state.position);

    // Check if track ended for "end of track" sleep timer
    // This is handled by listening to track changes
    // Note: We'd need a more sophisticated approach for real "end of track" detection

    final dismissProgress = (_dragOffset / 300).clamp(0.0, 1.0);
    final scale = 1.0 - dismissProgress * 0.05;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Stack(
            children: [
              // Background atmosphere
              Positioned.fill(
                child: PowerampBackground(artworkPath: artworkPath),
              ),

              // Main content - NO TOP BAR, dismiss via swipe only
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: _onDismissDragUpdate,
                onVerticalDragEnd: _onDismissDragEnd,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Swipe handle indicator (subtle)
                      SizedBox(height: topPadding > 0 ? 8 : 16),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Main scrollable content
                      Expanded(
                        child: track == null
                            ? const _EmptyState()
                            : _MainContent(
                                state: state,
                                artworkPath: artworkPath,
                                scrubController: _scrubController,
                                sleepTimerController: _sleepTimerController,
                                currentIndex: state.currentIndex ?? 0,
                                queueLength: state.queue.length,
                                getArtworkPath: _getArtworkPathForIndex,
                                onPrevious: () => ctrl.previous(),
                                onNext: () => ctrl.next(),
                                onPlayPause: () => ctrl.togglePlayPause(),
                                onInnerPreviousHoldChange: (holding) {
                                  if (holding) {
                                    _startContinuousSeek(true);
                                  } else {
                                    _stopContinuousSeek();
                                  }
                                },
                                onInnerNextHoldChange: (holding) {
                                  if (holding) {
                                    _startContinuousSeek(false);
                                  } else {
                                    _stopContinuousSeek();
                                  }
                                },
                                onShuffleTap: () => ctrl.toggleShuffle(),
                                onRepeatTap: () => ctrl.toggleRepeat(),
                                onQueueTap: _openQueue,
                                onSleepTap: _openSleepTimer,
                                onMenuTap: () => _openTrackMenu(track.filePath),
                              ),
                      ),

                      // Bottom nav bar
                      Padding(
                        padding: EdgeInsets.only(bottom: bottomPadding + 12),
                        child: PowerampBottomNav(
                          selectedIndex: _bottomNavIndex,
                          onTap: _handleBottomNavTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.20),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing Playing',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.50),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final PlaybackState state;
  final String? artworkPath;
  final ScrubController scrubController;
  final SleepTimerController sleepTimerController;
  final int currentIndex;
  final int queueLength;
  final String? Function(int index) getArtworkPath;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final ValueChanged<bool> onInnerPreviousHoldChange;
  final ValueChanged<bool> onInnerNextHoldChange;
  final VoidCallback onShuffleTap;
  final VoidCallback onRepeatTap;
  final VoidCallback onQueueTap;
  final VoidCallback onSleepTap;
  final VoidCallback onMenuTap;

  const _MainContent({
    required this.state,
    required this.artworkPath,
    required this.scrubController,
    required this.sleepTimerController,
    required this.currentIndex,
    required this.queueLength,
    required this.getArtworkPath,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onInnerPreviousHoldChange,
    required this.onInnerNextHoldChange,
    required this.onShuffleTap,
    required this.onRepeatTap,
    required this.onQueueTap,
    required this.onSleepTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;

    return Column(
      children: [
        const SizedBox(height: 8),

        // Artwork with PageView swipe and overlays
        Center(
          child: PowerampArtworkPageView(
            currentIndex: currentIndex,
            queueLength: queueLength,
            getArtworkPath: getArtworkPath,
            onPrevious: onPrevious,
            onNext: onNext,
            onMenuTap: onMenuTap,
          ),
        ),

        const SizedBox(height: 20),

        // Metadata block (left-aligned)
        PowerampMetadataBlock(
          title: track.displayTitle,
          artist: track.artist,
          album: track.album,
        ),

        const SizedBox(height: 18),

        // Utility row: Queue, Sleep Timer, Repeat, Shuffle
        PowerampUtilityRow(
          shuffleEnabled: state.shuffleEnabled,
          repeatMode: state.repeatMode,
          sleepTimerController: sleepTimerController,
          onShuffleTap: onShuffleTap,
          onRepeatTap: onRepeatTap,
          onQueueTap: onQueueTap,
          onSleepTap: onSleepTap,
        ),

        const Spacer(),

        // Combined WaveSeek + Transport zone
        PowerampWaveseekTransport(
          state: state,
          scrubController: scrubController,
          trackId: track.filePath.hashCode,
          onPrevious: onPrevious,
          onNext: onNext,
          onPlayPause: onPlayPause,
          onInnerPreviousHoldChange: onInnerPreviousHoldChange,
          onInnerNextHoldChange: onInnerNextHoldChange,
        ),

        const SizedBox(height: 10),

        // Time pills
        ListenableBuilder(
          listenable: scrubController,
          builder: (context, _) {
            return PowerampTimePills(
              position: scrubController.displayPosition,
              duration: state.duration,
            );
          },
        ),

        const SizedBox(height: 16),

        // Tech info line
        PowerampTechInfo(
          trackPath: track.filePath,
          isCue: track.start != null,
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

/// Placeholder for equalizer - avoids circular import
class _EqualizerPlaceholder extends StatelessWidget {
  const _EqualizerPlaceholder();

  @override
  Widget build(BuildContext context) {
    // This should be replaced with actual EqualizerTab import
    // For now, show a message
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.equalizer_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.40),
            ),
            const SizedBox(height: 16),
            Text(
              'Equalizer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
