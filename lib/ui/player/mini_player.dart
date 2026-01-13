import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/domain/state/playback_state.dart';
import 'package:ghostmusic/ui/artwork/artwork_view.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

import 'package:ghostmusic/ui/widgets/glass_surface.dart';
import 'package:ghostmusic/ui/player/gesture_surface.dart';
import 'package:ghostmusic/ui/artwork/cover_picker_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;

  const MiniPlayer({
    super.key,
    this.onTap,
    this.onNext,
    this.onPrevious,
    this.onPlayPause,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);

    if (!state.hasTrack || state.currentTrack == null) {
      return const SizedBox.shrink();
    }

    return GestureSurface(
      onNext: onNext,
      onPrev: onPrevious,
      onSwipeUp: onTap,
      swipeThreshold: 36,
      velocityThreshold: 240,
      enableVerticalSwipe: true,

      enableHorizontalSwipe: true,
      showSwipeIndicator: false,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _MiniPlayerContent(
          state: state,
          onPlayPause: onPlayPause,
          onPrevious: onPrevious,
          onNext: onNext,
          onCoverPick: () {
            final track = state.currentTrack;
            if (track == null) return;
            CoverPickerSheet.show(context, track.filePath);
          },
        ),
      ),

    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final PlaybackState state;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onCoverPick;

  const _MiniPlayerContent({
    required this.state,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onCoverPick,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final track = state.currentTrack!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        return SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassSurface.miniPlayer(
                child: SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: onCoverPick,
                              onLongPress: onCoverPick,
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _TrackArtworkMini(trackPath: track.filePath),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: cs.favorite,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: cs.surface,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.image_search_rounded,
                                          size: 9,
                                          color: cs.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TrackInfo(
                                title: track.displayTitle,
                                subtitle: track.artist ?? _extractPathInfo(track.filePath),
                              ),
                            ),
                            if (state.mixPhase != MixPhase.off) ...[
                              const SizedBox(width: 10),
                              _MiniMixBadge(
                                phase: state.mixPhase,
                                progress01: state.mixProgress01,
                              ),
                            ],
                          ],
                        ),

                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _MiniProgressRow(
                          position: state.position,
                          duration: state.duration,
                          progress: state.progress01,
                          accent: cs.favorite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _MiniActionsBar(
                isPlaying: state.isPlaying,
                onPrevious: onPrevious,
                onPlayPause: onPlayPause,
                onNext: onNext,
              ),
            ],
          ),
        );
      },
    );

  }

  String _extractPathInfo(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return '';
  }
}

class _TrackArtworkMini extends StatelessWidget {
  final String trackPath;

  const _TrackArtworkMini({required this.trackPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child: TrackArtwork(
          trackPath: trackPath,
          size: 44,
          radius: 10,
        ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TrackInfo({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniMixBadge extends StatefulWidget {
  final MixPhase phase;
  final double progress01;

  const _MiniMixBadge({
    required this.phase,
    required this.progress01,
  });

  @override
  State<_MiniMixBadge> createState() => _MiniMixBadgeState();
}

class _MiniMixBadgeState extends State<_MiniMixBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.gradientShift,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _MiniMixBadge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.phase == MixPhase.off) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    final pulse = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);

    final bgBase = accent.withValues(alpha: widget.phase == MixPhase.mixing ? 0.14 : 0.10);
    final bg = Color.lerp(bgBase, accent.withValues(alpha: 0.20), pulse)!;
    final border = Color.lerp(accent.withValues(alpha: 0.20), accent.withValues(alpha: 0.34), pulse)!;
    final fg = Color.lerp(accent.withValues(alpha: 0.70), accent.withValues(alpha: 0.95), pulse)!;

    final progress = widget.phase == MixPhase.mixing
        ? widget.progress01.clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      height: 22,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: bg)),
            if (widget.phase == MixPhase.mixing)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: ColoredBox(color: accent.withValues(alpha: 0.28)),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: border, width: 1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: fg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25 + 0.35 * pulse),
                          blurRadius: 10,
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MIX',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      height: 1.0,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniProgressRow extends StatelessWidget {

  final Duration position;
  final Duration? duration;
  final double progress;
  final Color accent;

  const _MiniProgressRow({
    required this.position,
    required this.duration,
    required this.progress,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: cs.onSurface.withValues(alpha: 0.55),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final total = duration;
    final totalLabel = total == null || total.inMilliseconds <= 0
        ? '--:--'
        : _formatDuration(total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_formatDuration(position), style: labelStyle),
              const Spacer(),
              Text(totalLabel, style: labelStyle),
            ],
          ),
          const SizedBox(height: 2),
          _ProgressIndicator(
            progress: progress,
            color: accent,
            height: 4,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }

    return '$minutes:${twoDigits(seconds)}';
  }
}

class _MiniActionsBar extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;

  const _MiniActionsBar({
    required this.isPlaying,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface.bar(
      variant: GlassVariant.ultraThin,
      sigma: AppBlur.tabBar,
      radius: 999,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PrevButton(onPressed: onPrevious),
          _PlayPauseButton(isPlaying: isPlaying, onPressed: onPlayPause),
          _NextButton(onPressed: onNext),
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.favorite.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(widget.isPlaying),
              size: 24,
              color: cs.favorite,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrevButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _PrevButton({this.onPressed});

  @override
  State<_PrevButton> createState() => _PrevButtonState();
}

class _PrevButtonState extends State<_PrevButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
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
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            Icons.skip_previous_rounded,
            size: 26,
            color: cs.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _NextButton({this.onPressed});

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
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
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            Icons.skip_next_rounded,
            size: 26,
            color: cs.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final double progress;
  final Color color;
  final double height;

  const _ProgressIndicator({
    required this.progress,
    required this.color,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: cs.onSurface.withValues(alpha: 0.12)),
            ),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniPlayerSkeleton extends StatelessWidget {
  const MiniPlayerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassSurface.miniPlayer(
          child: SizedBox(
            height: 60,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 140,
                              height: 14,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 92,
                              height: 10,
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 0,
                  child: _ProgressIndicator(
                    progress: 0.35,
                    color: cs.favorite,
                    height: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        GlassSurface.bar(
          variant: GlassVariant.ultraThin,
          radius: 999,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.favorite.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}