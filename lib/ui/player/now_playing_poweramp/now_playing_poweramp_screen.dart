import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/domain/state/playback_state.dart';
import 'package:ghostmusic/ui/artwork/cover_picker_sheet.dart';
import 'package:ghostmusic/ui/audio/equalizer_tab.dart';
import 'package:ghostmusic/ui/library/tag_editor_sheet.dart';
import 'package:ghostmusic/ui/player/queue_sheet.dart';

import 'components/poweramp_artwork_card.dart';
import 'components/poweramp_background.dart';
import 'components/poweramp_bottom_nav.dart';
import 'components/poweramp_metadata_block.dart';
import 'components/poweramp_tech_info.dart';
import 'components/poweramp_time_pills.dart';
import 'components/poweramp_transport_controls.dart';
import 'components/poweramp_utility_row.dart';
import 'components/poweramp_waveseek_surface.dart';
import 'state/scrub_controller.dart';

/// Poweramp-style Now Playing screen - complete rewrite.
///
/// This replaces the old Now Playing screen with a 1:1 Poweramp layout:
/// - Top bar (back, queue)
/// - Large artwork with overlays
/// - Metadata (title, artist)
/// - Utility row (visualizer, sleep, repeat, shuffle)
/// - WaveSeek surface with transport controls overlay
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
  late final AnimationController _dismissController;

  double _dragOffset = 0.0;
  int _bottomNavIndex = 0;

  // For continuous seek during long press
  Timer? _seekTimer;

  @override
  void initState() {
    super.initState();

    _scrubController = ScrubController(
      onSeek: _performSeek,
      hapticsEnabled: true,
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
    _dismissController.dispose();
    _seekTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSeek(Duration position) async {
    final ctrl = ref.read(playbackControllerProvider.notifier);
    await ctrl.seek(position);
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

  void _openEqualizer() {
    HapticFeedback.selectionClick();
    final size = MediaQuery.sizeOf(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => SizedBox(
        height: size.height * 0.92,
        child: const SafeArea(child: EqualizerTab()),
      ),
    );
  }

  void _openTrackMenu(String trackPath) {
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1E24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.image_search_rounded, color: Colors.white70),
                  title: const Text('Cover Art...', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    CoverPickerSheet.show(context, trackPath);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Colors.white70),
                  title: const Text('Edit Tags...', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    TagEditorSheet.show(context, trackPath);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    if (_scrubController.isScrubbing) return;
    if (details.delta.dy <= 0) return;

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
        // EQ
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

    // Update scrub controller with current state
    _scrubController.setTrackDuration(state.duration ?? Duration.zero);
    _scrubController.updatePlaybackPosition(state.position);

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

              // Main content
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: _onDismissDragUpdate,
                onVerticalDragEnd: _onDismissDragEnd,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top bar
                      _TopBar(
                        onBack: _close,
                        onQueue: state.hasQueue ? _openQueue : null,
                      ),

                      // Main scrollable content
                      Expanded(
                        child: track == null
                            ? const _EmptyState()
                            : _MainContent(
                                state: state,
                                artworkPath: artworkPath,
                                scrubController: _scrubController,
                                onPrevious: () => ctrl.previous(),
                                onNext: () => ctrl.next(),
                                onPlayPause: () => ctrl.togglePlayPause(),
                                onFastRewind: () => ctrl.previous(),
                                onFastForward: () => ctrl.next(),
                                onPreviousHoldChange: (holding) {
                                  if (holding) {
                                    _startContinuousSeek(true);
                                  } else {
                                    _stopContinuousSeek();
                                  }
                                },
                                onNextHoldChange: (holding) {
                                  if (holding) {
                                    _startContinuousSeek(false);
                                  } else {
                                    _stopContinuousSeek();
                                  }
                                },
                                onShuffleTap: () => ctrl.toggleShuffle(),
                                onRepeatTap: () => ctrl.toggleRepeat(),
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

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onQueue;

  const _TopBar({
    required this.onBack,
    this.onQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            color: Colors.white.withValues(alpha: 0.85),
            tooltip: 'Close',
          ),

          // Queue button
          if (onQueue != null)
            IconButton(
              onPressed: onQueue,
              icon: const Icon(Icons.queue_music_rounded, size: 26),
              color: Colors.white.withValues(alpha: 0.70),
              tooltip: 'Queue',
            ),
        ],
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
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final VoidCallback onFastRewind;
  final VoidCallback onFastForward;
  final ValueChanged<bool> onPreviousHoldChange;
  final ValueChanged<bool> onNextHoldChange;
  final VoidCallback onShuffleTap;
  final VoidCallback onRepeatTap;
  final VoidCallback onMenuTap;

  const _MainContent({
    required this.state,
    required this.artworkPath,
    required this.scrubController,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onFastRewind,
    required this.onFastForward,
    required this.onPreviousHoldChange,
    required this.onNextHoldChange,
    required this.onShuffleTap,
    required this.onRepeatTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;

    return Column(
      children: [
        const SizedBox(height: 12),

        // Artwork card with overlays
        Center(
          child: PowerampArtworkCard(
            artworkPath: artworkPath,
            onPrevious: onPrevious,
            onNext: onNext,
            onLongPress: onMenuTap,
            onMenuTap: onMenuTap,
          ),
        ),

        const SizedBox(height: 20),

        // Metadata block
        PowerampMetadataBlock(
          title: track.displayTitle,
          artist: track.artist,
          album: track.album,
        ),

        const SizedBox(height: 18),

        // Utility row
        PowerampUtilityRow(
          shuffleEnabled: state.shuffleEnabled,
          repeatMode: state.repeatMode,
          onShuffleTap: onShuffleTap,
          onRepeatTap: onRepeatTap,
        ),

        const Spacer(),

        // WaveSeek + Transport zone
        _WaveseekTransportZone(
          state: state,
          scrubController: scrubController,
          trackId: track.filePath.hashCode,
          onPrevious: onPrevious,
          onNext: onNext,
          onPlayPause: onPlayPause,
          onFastRewind: onFastRewind,
          onFastForward: onFastForward,
          onPreviousHoldChange: onPreviousHoldChange,
          onNextHoldChange: onNextHoldChange,
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

/// Combined WaveSeek surface with transport controls overlay.
///
/// CRITICAL: The waveseek surface captures all gestures.
/// Transport controls fade and ignore pointer during scrubbing.
class _WaveseekTransportZone extends StatelessWidget {
  final PlaybackState state;
  final ScrubController scrubController;
  final int trackId;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final VoidCallback onFastRewind;
  final VoidCallback onFastForward;
  final ValueChanged<bool> onPreviousHoldChange;
  final ValueChanged<bool> onNextHoldChange;

  const _WaveseekTransportZone({
    required this.state,
    required this.scrubController,
    required this.trackId,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.onFastRewind,
    required this.onFastForward,
    required this.onPreviousHoldChange,
    required this.onNextHoldChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // WaveSeek surface (captures all gestures)
            Positioned.fill(
              child: PowerampWaveseekSurface(
                scrubController: scrubController,
                trackId: trackId,
                height: 90,
              ),
            ),

            // Transport controls (overlay, fades during scrub)
            ListenableBuilder(
              listenable: scrubController,
              builder: (context, _) {
                return PowerampTransportControls(
                  isPlaying: state.isPlaying,
                  isScrubbing: scrubController.isScrubbing,
                  onPlayPause: onPlayPause,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onFastRewind: onFastRewind,
                  onFastForward: onFastForward,
                  onPreviousHoldChange: onPreviousHoldChange,
                  onNextHoldChange: onNextHoldChange,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
