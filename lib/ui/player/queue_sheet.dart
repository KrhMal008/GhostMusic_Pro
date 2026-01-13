import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/models/track.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/domain/state/playback_state.dart';
import 'package:ghostmusic/ui/artwork/artwork_view.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';

class QueueSheet extends ConsumerWidget {
  final ScrollController? scrollController;

  const QueueSheet({
    super.key,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final ctrl = ref.read(playbackControllerProvider.notifier);

    return _QueueSheetContent(
      state: state,
      scrollController: scrollController,
      onTrackTap: (index) {
        HapticFeedback.selectionClick();
        ctrl.seekToIndex(index);
      },
    );
  }
}

class _QueueSheetContent extends StatelessWidget {
  final PlaybackState state;
  final ScrollController? scrollController;
  final ValueChanged<int> onTrackTap;

  const _QueueSheetContent({
    required this.state,
    this.scrollController,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: cs.onSurface.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              _QueueHeader(
                totalTracks: state.queue.length,
                currentIndex: state.currentIndex,
              ),
              Expanded(
                child: state.queue.isEmpty
                    ? _EmptyQueue()
                    : _QueueList(
                        queue: state.queue,
                        currentIndex: state.currentIndex,
                        scrollController: scrollController,
                        onTrackTap: onTrackTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  final int totalTracks;
  final int? currentIndex;

  const _QueueHeader({
    required this.totalTracks,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Up Next',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildSubtitle(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GlassSurface.chip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music_rounded,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$totalTracks',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(
          height: 1,
          color: cs.onSurface.withValues(alpha: 0.08),
        ),
      ],
    );
  }

  String _buildSubtitle() {
    if (currentIndex == null || totalTracks == 0) {
      return 'No tracks in queue';
    }
    final remaining = totalTracks - currentIndex! - 1;
    if (remaining <= 0) {
      return 'Last track';
    }
    return '$remaining tracks remaining';
  }
}

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 56,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Queue is empty',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add tracks to play next',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  final List<Track> queue;
  final int? currentIndex;
  final ScrollController? scrollController;
  final ValueChanged<int> onTrackTap;

  const _QueueList({
    required this.queue,
    required this.currentIndex,
    this.scrollController,
    required this.onTrackTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final track = queue[index];
        final isPlaying = index == currentIndex;
        final isPast = currentIndex != null && index < currentIndex!;

        return _QueueTrackTile(
          track: track,
          index: index,
          isPlaying: isPlaying,
          isPast: isPast,
          onTap: () => onTrackTap(index),
        );
      },
    );
  }
}

class _QueueTrackTile extends StatefulWidget {
  final Track track;
  final int index;
  final bool isPlaying;
  final bool isPast;
  final VoidCallback onTap;

  const _QueueTrackTile({
    required this.track,
    required this.index,
    required this.isPlaying,
    required this.isPast,
    required this.onTap,
  });

  @override
  State<_QueueTrackTile> createState() => _QueueTrackTileState();
}

class _QueueTrackTileState extends State<_QueueTrackTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isPressed) {
      _isPressed = true;
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      _isPressed = false;
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      _isPressed = false;
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final opacity = widget.isPast ? 0.45 : 1.0;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isPlaying
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: widget.isPlaying
                        ? _NowPlayingIndicator()
                        : Text(
                            '${widget.index + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: TrackArtwork(
                        trackPath: widget.track.filePath,
                        size: 44,
                        radius: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                widget.isPlaying ? FontWeight.w600 : FontWeight.w500,
                            color: widget.isPlaying
                                ? cs.primary
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.track.artist ?? _extractFolder(widget.track.filePath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.drag_handle_rounded,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _extractFolder(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return '';
  }
}

class _NowPlayingIndicator extends StatefulWidget {
  @override
  State<_NowPlayingIndicator> createState() => _NowPlayingIndicatorState();
}

class _NowPlayingIndicatorState extends State<_NowPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(cs.primary, 0.0),
            const SizedBox(width: 2),
            _buildBar(cs.primary, 0.2),
            const SizedBox(width: 2),
            _buildBar(cs.primary, 0.4),
          ],
        );
      },
    );
  }

  Widget _buildBar(Color color, double delay) {
    final value = (_controller.value + delay) % 1.0;
    final height = 8 + (8 * value);

    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

class QueueTrackContextMenu extends StatelessWidget {
  final Track track;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToEnd;
  final VoidCallback? onRemove;
  final VoidCallback? onGoToAlbum;
  final VoidCallback? onGoToArtist;

  const QueueTrackContextMenu({
    super.key,
    required this.track,
    this.onPlayNext,
    this.onAddToEnd,
    this.onRemove,
    this.onGoToAlbum,
    this.onGoToArtist,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassSurface.contextMenu(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ContextMenuHeader(track: track),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          if (onPlayNext != null)
            _ContextMenuItem(
              icon: Icons.play_arrow_rounded,
              label: 'Play Next',
              onTap: onPlayNext!,
            ),
          if (onAddToEnd != null)
            _ContextMenuItem(
              icon: Icons.playlist_add_rounded,
              label: 'Add to End of Queue',
              onTap: onAddToEnd!,
            ),
          if (onRemove != null)
            _ContextMenuItem(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Remove from Queue',
              onTap: onRemove!,
              isDestructive: true,
            ),
          Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
          if (onGoToAlbum != null)
            _ContextMenuItem(
              icon: Icons.album_rounded,
              label: 'Go to Album',
              onTap: onGoToAlbum!,
            ),
          if (onGoToArtist != null)
            _ContextMenuItem(
              icon: Icons.person_rounded,
              label: 'Go to Artist',
              onTap: onGoToArtist!,
            ),
        ],
      ),
    );
  }
}

class _ContextMenuHeader extends StatelessWidget {
  final Track track;

  const _ContextMenuHeader({required this.track});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: TrackArtwork(
                trackPath: track.filePath,
                size: 48,
                radius: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (track.artist != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    track.artist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : cs.onSurface;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color.withValues(alpha: 0.85)),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}