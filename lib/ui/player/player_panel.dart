import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;

import 'package:ghostmusic/domain/services/cover_art_service.dart';
import 'package:ghostmusic/domain/state/library_controller.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/domain/state/playback_state.dart';

import 'package:ghostmusic/ui/artwork/artwork_view.dart';
import 'package:ghostmusic/ui/artwork/cover_picker_sheet.dart';
import 'package:ghostmusic/ui/audio/equalizer_tab.dart';
import 'package:ghostmusic/ui/library/tag_editor_sheet.dart';
import 'package:ghostmusic/ui/player/queue_sheet.dart';
import 'package:ghostmusic/ui/player/waveform_seek_bar.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';

// =============================================================================
// DESIGN SPEC (Reference-based premium audiophile UI)
// =============================================================================
//
// LAYOUT:
// - Horizontal margin: 24dp
// - Artwork corner radius: 24dp
// - Artwork shadow: soft drop shadow, offset (0, 16), blur 32
// - Title: 26sp, bold, white 100%
// - Artist/Album: 16sp, medium, white 65%
// - Time labels: 13sp, semibold, white 55%
// - Tech info: 11sp, semibold, letter-spacing 1.2, white 45%
//
// CONTROLS:
// - Play/Pause: 72dp diameter, black circle, white icon 44dp
// - Prev/Next: 52dp diameter, black circle, white icon 28dp
// - Secondary: 44dp hit target, icon 22dp, white 75%
//
// WAVEFORM:
// - Height: 70dp
// - Bar width: ~3dp, spacing ~2dp
// - Played: white 95%, Unplayed: white 40%
//
// BACKGROUND:
// - Artwork-derived palette, heavily blurred (sigma 50+)
// - Dark gradient overlay (top to bottom)
// - Vignette (radial from center)
// - Subtle noise texture (3.5% opacity)
// =============================================================================

class PlayerPanel extends ConsumerStatefulWidget {
  const PlayerPanel({super.key});

  @override
  ConsumerState<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends ConsumerState<PlayerPanel>
    with TickerProviderStateMixin {
  // Seek
  bool _isDraggingSeek = false;
  double _dragSeekValue = 0.0;

  // Dismiss drag
  double _dragOffset = 0.0;
  late final AnimationController _dismissController;
  late Animation<double> _dragOffsetAnim;

  // Artwork intro anim
  late final AnimationController _artworkIntroController;
  late final Animation<double> _artworkScaleAnimation;

  @override
  void initState() {
    super.initState();

    _artworkIntroController = AnimationController(
      vsync: this,
      duration: AppDuration.slow,
    );
    _artworkScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _artworkIntroController, curve: AppCurves.enter),
    );
    _artworkIntroController.forward();

    _dismissController = AnimationController(
      vsync: this,
      duration: AppDuration.medium,
    );

    _dragOffsetAnim = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _artworkIntroController.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  void _close() {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
  }

  double _maxDrag(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.75;

  double _effectiveOffset() {
    if (_dismissController.isAnimating) return _dragOffsetAnim.value;
    return _dragOffset;
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    if (_isDraggingSeek) return;

    final dy = details.delta.dy;
    if (dy <= 0) return;

    if (_dismissController.isAnimating) {
      _dragOffset = _dragOffsetAnim.value;
      _dismissController.stop();
      _dragOffsetAnim = AlwaysStoppedAnimation(_dragOffset);
    }

    final maxDrag = _maxDrag(context);
    setState(() {
      _dragOffset = (_dragOffset + dy).clamp(0.0, maxDrag);
      _dragOffsetAnim = AlwaysStoppedAnimation(_dragOffset);
    });
  }

  void _onDismissDragEnd(DragEndDetails details) {
    if (_isDraggingSeek) return;

    final maxDrag = _maxDrag(context);
    const dismissThreshold = 120.0;
    const dismissVelocity = 900.0;

    final vy = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = _dragOffset > dismissThreshold || vy > dismissVelocity;

    if (shouldDismiss) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    _dragOffsetAnim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: AppCurves.exit),
    );

    _dismissController.forward(from: 0.0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _dragOffset = 0.0;
        _dragOffsetAnim = const AlwaysStoppedAnimation(0.0);
      });
    });

    _dragOffset = _dragOffset.clamp(0.0, maxDrag);
  }

  void _openQueue() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
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
    final size = MediaQuery.of(context).size;

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

  void _openMore(String trackPath) {
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface(
              variant: GlassVariant.solid,
              shape: GlassShape.roundedLarge,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_search_rounded),
                    title: const Text('Cover Art...'),
                    subtitle: const Text('Choose or fetch artwork'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      CoverPickerSheet.show(context, trackPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Edit Tags...'),
                    subtitle: const Text('Artist / Album metadata'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      TagEditorSheet.show(context, trackPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_rounded),
                    title: const Text('Move / Copy...'),
                    subtitle: const Text('To folder on disk'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openMoveCopy(trackPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Rescan Artwork'),
                    subtitle: const Text('Clear cache and retry'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await CoverArtService.clearNetCacheForFile(trackPath);
                        await CoverArtService.getOrFetchForFile(trackPath);
                      } catch (_) {}

                      if (!mounted) return;
                      ref.invalidate(trackArtworkPathProvider(trackPath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Artwork rescan started')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMoveCopy(String trackPath) {
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface(
              variant: GlassVariant.solid,
              shape: GlassShape.roundedLarge,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.copy_all_rounded),
                    title: const Text('Copy to folder...'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _moveOrCopyToFolder(trackPath, move: false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_rounded),
                    title: const Text('Move to folder...'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _moveOrCopyToFolder(trackPath, move: true);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveOrCopyToFolder(String trackPath, {required bool move}) async {
    final messenger = ScaffoldMessenger.of(context);
    final playback = ref.read(playbackControllerProvider);
    final ctrl = ref.read(playbackControllerProvider.notifier);

    final destinationFolder = await _pickDestinationFolder();
    if (destinationFolder == null || destinationFolder.trim().isEmpty) return;

    try {
      final newPath = await _copyOrMoveFileToDirectory(
        srcPath: trackPath,
        destDir: destinationFolder,
        move: move,
      );

      if (newPath == null) return;

      if (move && playback.currentTrack?.filePath == trackPath) {
        final wasPlaying = playback.isPlaying;
        final pos = playback.position;
        final currentIndex = playback.currentIndex ?? 0;

        if (wasPlaying) await ctrl.togglePlayPause();

        final updatedQueue = playback.queue
            .map((t) => t.filePath == trackPath ? t.copyWith(filePath: newPath) : t)
            .toList(growable: false);

        await ctrl.setQueue(updatedQueue, startIndex: currentIndex, autoplay: false);
        await ctrl.seek(pos);

        if (wasPlaying) await ctrl.togglePlayPause();
      }

      ref.read(libraryControllerProvider.notifier).rescan();

      messenger.showSnackBar(
        SnackBar(
          content: Text(move ? 'Moved to: $destinationFolder' : 'Copied to: $destinationFolder'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to ${move ? 'move' : 'copy'}: $e')),
      );
    }
  }

  Future<String?> _pickDestinationFolder() {
    final library = ref.read(libraryControllerProvider);
    final folders = library.folders;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface(
              variant: GlassVariant.solid,
              shape: GlassShape.roundedLarge,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final f in folders)
                    ListTile(
                      leading: const Icon(Icons.folder_rounded),
                      title: Text(p.basename(f).isEmpty ? f : p.basename(f)),
                      subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(ctx).pop(f),
                    ),
                  if (folders.isNotEmpty)
                    Divider(
                      height: 1,
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ListTile(
                    leading: const Icon(Icons.folder_open_rounded),
                    title: const Text('Choose another folder...'),
                    subtitle: const Text('Via system dialog'),
                    onTap: () async {
                      final picked = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Choose folder',
                        lockParentWindow: true,
                      );
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(picked);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _copyOrMoveFileToDirectory({
    required String srcPath,
    required String destDir,
    required bool move,
  }) async {
    final src = File(srcPath);
    if (!await src.exists()) throw Exception('File not found');

    final targetDir = Directory(destDir);
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final base = p.basenameWithoutExtension(srcPath);
    final ext = p.extension(srcPath);

    String candidate(int? i) {
      final suffix = (i == null || i == 0) ? '' : ' ($i)';
      return p.join(destDir, '$base$suffix$ext');
    }

    var outPath = candidate(0);
    var n = 0;
    while (await File(outPath).exists()) {
      n++;
      outPath = candidate(n);
      if (n > 999) throw Exception('Too many files with same name');
    }

    if (!move) {
      await src.copy(outPath);
      return outPath;
    }

    try {
      await src.rename(outPath);
      return outPath;
    } catch (_) {
      await src.copy(outPath);
      try {
        await src.delete();
      } catch (_) {}
      return outPath;
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

    final mq = MediaQuery.of(context);
    final topPadding = mq.padding.top;
    final bottomPadding = mq.padding.bottom;

    return AnimatedBuilder(
      animation: _dismissController,
      builder: (context, child) {
        final maxDrag = _maxDrag(context);
        final offset = _effectiveOffset();

        final t = (offset / maxDrag).clamp(0.0, 1.0);
        final scale = lerpDouble(1.0, 0.94, t)!;

        return Transform.translate(
          offset: Offset(0, offset),
          child: Transform.scale(
            alignment: Alignment.topCenter,
            scale: scale,
            child: child,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Base black background
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

            // Artwork-derived blurred atmosphere background
            Positioned.fill(
              child: _AtmosphereBackground(artworkAsync: artworkAsync),
            ),

            // Vignette overlay
            const Positioned.fill(child: _VignetteOverlay()),

            // Noise texture overlay
            const Positioned.fill(child: _NoiseOverlay(opacity: 0.035)),

            // Main content with drag-to-dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: _onDismissDragUpdate,
                onVerticalDragEnd: _onDismissDragEnd,
                child: Column(
                  children: [
                    SizedBox(height: topPadding),

                    // Header with handle and actions
                    _Header(
                      onClose: _close,
                      onOpenQueue: state.hasQueue ? _openQueue : null,
                      onOpenMore: track == null ? null : () => _openMore(track.filePath),
                      onDragUpdate: _onDismissDragUpdate,
                      onDragEnd: _onDismissDragEnd,
                    ),

                    // Main player content
                    Expanded(
                      child: track == null
                          ? const _EmptyState()
                          : _PlayerContent(
                              state: state,
                              artworkScale: _artworkScaleAnimation,
                              isDraggingSeek: _isDraggingSeek,
                              dragSeekValue: _dragSeekValue,
                              onSeekStart: (value) {
                                setState(() {
                                  _isDraggingSeek = true;
                                  _dragSeekValue = value;
                                });
                              },
                              onSeekUpdate: (value) => setState(() => _dragSeekValue = value),
                              onSeekEnd: (value) async {
                                final duration = state.duration;
                                if (duration != null) {
                                  final seekMs = (duration.inMilliseconds * value).round();
                                  await ctrl.seek(Duration(milliseconds: seekMs));
                                }
                                if (!mounted) return;
                                setState(() => _isDraggingSeek = false);
                              },
                              onPlayPause: () => ctrl.togglePlayPause(),
                              onNext: () => ctrl.next(),
                              onPrevious: () => ctrl.previous(),
                              onToggleShuffle: () => ctrl.toggleShuffle(),
                              onToggleRepeat: () => ctrl.toggleRepeat(),
                              onOpenQueue: state.hasQueue ? _openQueue : null,
                              onOpenEqualizer: _openEqualizer,
                              onOpenMore: () => _openMore(track.filePath),
                            ),
                    ),

                    // Tech info line at bottom
                    if (track != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 24,
                          right: 24,
                          bottom: bottomPadding + 20,
                        ),
                        child: _TechInfoLine(trackPath: track.filePath),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ATMOSPHERE BACKGROUND
// =============================================================================

class _AtmosphereBackground extends StatelessWidget {
  final AsyncValue<String?> artworkAsync;

  const _AtmosphereBackground({required this.artworkAsync});

  @override
  Widget build(BuildContext context) {
    return artworkAsync.when(
      data: (path) {
        if (path == null) return const _DefaultGradientBackground();
        return _ArtworkAtmosphere(artworkPath: path);
      },
      loading: () => const _DefaultGradientBackground(),
      error: (_, __) => const _DefaultGradientBackground(),
    );
  }
}

class _ArtworkAtmosphere extends StatefulWidget {
  final String artworkPath;

  const _ArtworkAtmosphere({required this.artworkPath});

  @override
  State<_ArtworkAtmosphere> createState() => _ArtworkAtmosphereState();
}

class _ArtworkAtmosphereState extends State<_ArtworkAtmosphere> {
  PaletteGenerator? _palette;
  bool _paletteLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(covariant _ArtworkAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkPath != widget.artworkPath) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    if (_paletteLoading) return;
    _paletteLoading = true;

    try {
      final file = File(widget.artworkPath);
      if (!await file.exists()) {
        _paletteLoading = false;
        return;
      }

      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(file),
        size: const Size(100, 100), // Downsample for performance
        maximumColorCount: 8,
      );

      if (mounted) {
        setState(() {
          _palette = palette;
          _paletteLoading = false;
        });
      }
    } catch (_) {
      _paletteLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    // Extract colors from palette or use defaults
    Color dominant = const Color(0xFF1A1A2E);
    Color muted = const Color(0xFF16213E);
    Color dark = const Color(0xFF0F0F1A);

    if (palette != null) {
      dominant = palette.dominantColor?.color ?? dominant;
      muted = palette.mutedColor?.color ?? palette.darkMutedColor?.color ?? muted;
      dark = palette.darkMutedColor?.color ?? palette.darkVibrantColor?.color ?? dark;

      // Darken all colors significantly for readability
      dominant = _darkenAndDesaturate(dominant, 0.20, 0.60);
      muted = _darkenAndDesaturate(muted, 0.15, 0.50);
      dark = _darkenAndDesaturate(dark, 0.08, 0.40);
    }

    return Stack(
      children: [
        // Blurred artwork image
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: AnimatedSwitcher(
              duration: AppDuration.smooth,
              child: Image.file(
                File(widget.artworkPath),
                key: ValueKey(widget.artworkPath),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),

        // Dark gradient overlay derived from palette
        AnimatedContainer(
          duration: AppDuration.smooth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                dominant.withValues(alpha: 0.85),
                muted.withValues(alpha: 0.90),
                dark.withValues(alpha: 0.95),
                Colors.black.withValues(alpha: 0.92),
              ],
              stops: const [0.0, 0.35, 0.70, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Color _darkenAndDesaturate(Color color, double lightness, double saturation) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * lightness).clamp(0.02, 0.15))
        .withSaturation((hsl.saturation * saturation).clamp(0.1, 0.5))
        .toColor();
  }
}

class _DefaultGradientBackground extends StatelessWidget {
  const _DefaultGradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            const Color(0xFF0F0F1A),
            Colors.black,
          ],
          stops: const [0.0, 0.35, 0.70, 1.0],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.3),
            radius: 1.3,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.25),
              Colors.black.withValues(alpha: 0.55),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NoiseOverlay extends StatelessWidget {
  final double opacity;
  const _NoiseOverlay({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _NoisePainter(opacity: opacity),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final double opacity;

  _NoisePainter({required this.opacity});

  static final List<Offset> _points = (() {
    final rnd = math.Random(1337);
    final list = <Offset>[];
    for (var i = 0; i < 1200; i++) {
      list.add(Offset(rnd.nextDouble(), rnd.nextDouble()));
    }
    return list;
  })();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final pts = _points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList(growable: false);
    canvas.drawPoints(PointMode.points, pts, paint);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}

// =============================================================================
// HEADER
// =============================================================================

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenMore;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _Header({
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.onOpenQueue,
    this.onOpenMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const GlassHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  color: Colors.white.withValues(alpha: 0.85),
                  tooltip: 'Close',
                ),
                const Spacer(),
                if (onOpenQueue != null)
                  IconButton(
                    onPressed: onOpenQueue,
                    icon: const Icon(Icons.queue_music_rounded, size: 24),
                    color: Colors.white.withValues(alpha: 0.70),
                    tooltip: 'Queue',
                  ),
                if (onOpenMore != null)
                  IconButton(
                    onPressed: onOpenMore,
                    icon: const Icon(Icons.more_horiz_rounded, size: 24),
                    color: Colors.white.withValues(alpha: 0.70),
                    tooltip: 'More',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.20)),
          const SizedBox(height: 16),
          Text(
            'Nothing Playing',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a track from your library',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PLAYER CONTENT
// =============================================================================

class _PlayerContent extends StatelessWidget {
  final PlaybackState state;
  final Animation<double> artworkScale;
  final bool isDraggingSeek;
  final double dragSeekValue;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onToggleRepeat;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenEqualizer;
  final VoidCallback? onOpenMore;

  const _PlayerContent({
    required this.state,
    required this.artworkScale,
    required this.isDraggingSeek,
    required this.dragSeekValue,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleShuffle,
    required this.onToggleRepeat,
    this.onOpenQueue,
    this.onOpenEqualizer,
    this.onOpenMore,
  });

  @override
  Widget build(BuildContext context) {
    final track = state.currentTrack!;
    final seekValue = isDraggingSeek ? dragSeekValue : state.progress01;

    final index = state.currentIndex;
    final total = state.queue.length;
    final queuePosition = (index != null && total > 0) ? '${index + 1} / $total' : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on screen height
        final isCompact = constraints.maxHeight < 600;
        final artworkPadding = isCompact ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: artworkPadding),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Artwork
              Expanded(
                flex: isCompact ? 4 : 5,
                child: Center(
                  child: ScaleTransition(
                    scale: artworkScale,
                    child: _ArtworkCard(trackPath: track.filePath),
                  ),
                ),
              ),

              SizedBox(height: isCompact ? 12 : 20),

              // Queue position indicator
              if (queuePosition != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    queuePosition,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.50),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

              // Track info
              _TrackInfo(
                title: track.displayTitle,
                artist: track.artist,
                album: track.album,
              ),

              SizedBox(height: isCompact ? 10 : 16),

              // Secondary controls (shuffle, repeat, etc.)
              _SecondaryActions(
                shuffleEnabled: state.shuffleEnabled,
                repeatMode: state.repeatMode,
                onShuffle: onToggleShuffle,
                onRepeat: onToggleRepeat,
                onEqualizer: onOpenEqualizer,
                onQueue: onOpenQueue,
              ),

              SizedBox(height: isCompact ? 14 : 22),

              // Waveform + Controls zone
              _WaveformControlsZone(
                progress: seekValue,
                position: state.position,
                duration: state.duration,
                isDragging: isDraggingSeek,
                dragValue: dragSeekValue,
                waveformSeed: track.filePath.hashCode,
                isPlaying: state.isPlaying,
                onSeekStart: onSeekStart,
                onSeekUpdate: onSeekUpdate,
                onSeekEnd: onSeekEnd,
                onPlayPause: onPlayPause,
                onNext: onNext,
                onPrevious: onPrevious,
              ),

              // Ghost mixing indicator
              _GhostMixingIndicator(
                phase: state.mixPhase,
                progress01: state.mixProgress01,
              ),

              SizedBox(height: isCompact ? 8 : 12),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// ARTWORK CARD
// =============================================================================

class _ArtworkCard extends StatelessWidget {
  final String trackPath;

  const _ArtworkCard({required this.trackPath});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: TrackArtwork(
                  trackPath: trackPath,
                  size: double.infinity,
                  radius: 24,
                  fit: BoxFit.cover,
                ),
              ),
              // Subtle border
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              // Subtle inner shine
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.08),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
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

// =============================================================================
// TRACK INFO
// =============================================================================

class _TrackInfo extends StatelessWidget {
  final String title;
  final String? artist;
  final String? album;

  const _TrackInfo({
    required this.title,
    this.artist,
    this.album,
  });

  @override
  Widget build(BuildContext context) {
    final artistText = artist?.trim();
    final albumText = album?.trim();

    final subtitleParts = <String>[];
    if (artistText != null && artistText.isNotEmpty) subtitleParts.add(artistText);
    if (albumText != null && albumText.isNotEmpty && albumText != artistText) subtitleParts.add(albumText);

    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' - ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// SECONDARY ACTIONS
// =============================================================================

class _SecondaryActions extends StatelessWidget {
  final bool shuffleEnabled;
  final int repeatMode;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback? onEqualizer;
  final VoidCallback? onQueue;

  const _SecondaryActions({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.onShuffle,
    required this.onRepeat,
    this.onEqualizer,
    this.onQueue,
  });

  IconData _repeatIcon() {
    if (repeatMode == 1) return Icons.repeat_one_rounded;
    return Icons.repeat_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final repeatActive = repeatMode != 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SecondaryButton(
          icon: Icons.equalizer_rounded,
          onTap: onEqualizer,
          active: false,
        ),
        const SizedBox(width: 24),
        _SecondaryButton(
          icon: Icons.shuffle_rounded,
          onTap: onShuffle,
          active: shuffleEnabled,
        ),
        const SizedBox(width: 24),
        _SecondaryButton(
          icon: _repeatIcon(),
          onTap: onRepeat,
          active: repeatActive,
        ),
        const SizedBox(width: 24),
        _SecondaryButton(
          icon: Icons.queue_music_rounded,
          onTap: onQueue,
          active: false,
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  const _SecondaryButton({
    required this.icon,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = active
        ? const Color(0xFF0A84FF)
        : enabled
            ? Colors.white.withValues(alpha: 0.70)
            : Colors.white.withValues(alpha: 0.30);

    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap?.call();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: active
            ? BoxDecoration(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }
}

// =============================================================================
// WAVEFORM + CONTROLS ZONE
// =============================================================================

class _WaveformControlsZone extends StatelessWidget {
  final double progress;
  final Duration position;
  final Duration? duration;
  final bool isDragging;
  final double dragValue;
  final int waveformSeed;
  final bool isPlaying;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const _WaveformControlsZone({
    required this.progress,
    required this.position,
    required this.duration,
    required this.isDragging,
    required this.dragValue,
    required this.waveformSeed,
    required this.isPlaying,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final d = duration;
    final clampedPosition = d == null
        ? position
        : Duration(milliseconds: position.inMilliseconds.clamp(0, d.inMilliseconds));

    var remaining = d == null ? null : (d - clampedPosition);
    if (remaining != null && remaining.isNegative) remaining = Duration.zero;

    return Column(
      children: [
        // Waveform with overlaid controls
        Stack(
          alignment: Alignment.center,
          children: [
            // Waveform seek bar
            WaveformSeekBar(
              progress: progress,
              position: clampedPosition,
              duration: d,
              isDragging: isDragging,
              dragValue: dragValue,
              onDragStart: onSeekStart,
              onDragUpdate: onSeekUpdate,
              onDragEnd: onSeekEnd,
              waveformSeed: waveformSeed,
              height: 70,
              playedColor: Colors.white,
              unplayedColor: Colors.white.withValues(alpha: 0.25),
            ),

            // Transport controls overlaid on waveform
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fast rewind (optional outer button)
                _TransportButton(
                  icon: Icons.fast_rewind_rounded,
                  size: 44,
                  iconSize: 22,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 8),

                // Previous
                _TransportButton(
                  icon: Icons.skip_previous_rounded,
                  size: 52,
                  iconSize: 28,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 12),

                // Play/Pause (dominant)
                _PlayPauseButton(
                  isPlaying: isPlaying,
                  onPressed: onPlayPause,
                ),
                const SizedBox(width: 12),

                // Next
                _TransportButton(
                  icon: Icons.skip_next_rounded,
                  size: 52,
                  iconSize: 28,
                  onTap: onNext,
                ),
                const SizedBox(width: 8),

                // Fast forward (optional outer button)
                _TransportButton(
                  icon: Icons.fast_forward_rounded,
                  size: 44,
                  iconSize: 22,
                  onTap: onNext,
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(clampedPosition),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                remaining != null ? formatDuration(remaining) : '--:--',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TRANSPORT BUTTONS (BLACK CIRCLES)
// =============================================================================

class _TransportButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _TransportButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  State<_TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<_TransportButton> {
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
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 12,
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.90),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.50),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// GHOST MIXING INDICATOR
// =============================================================================

class _GhostMixingIndicator extends StatefulWidget {
  final MixPhase phase;
  final double progress01;

  const _GhostMixingIndicator({
    required this.phase,
    required this.progress01,
  });

  @override
  State<_GhostMixingIndicator> createState() => _GhostMixingIndicatorState();
}

class _GhostMixingIndicatorState extends State<_GhostMixingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDuration.gradientShift);
    if (widget.phase != MixPhase.off) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _GhostMixingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    final shouldAnimate = widget.phase != MixPhase.off;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.phase == MixPhase.off) return const SizedBox(height: 8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        const accent = Color(0xFF0A84FF);
        final shimmer = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
        final progress = widget.phase == MixPhase.mixing ? widget.progress01.clamp(0.0, 1.0) : 0.0;

        final bg = Color.lerp(accent.withValues(alpha: 0.08), accent.withValues(alpha: 0.14), shimmer)!;
        final border = Color.lerp(accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.26), shimmer)!;
        final text = Color.lerp(Colors.white.withValues(alpha: 0.60), accent.withValues(alpha: 0.95), shimmer)!;

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
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
                          child: ColoredBox(color: accent.withValues(alpha: 0.20)),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: border, width: 1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.45 + 0.45 * shimmer),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.18 + 0.35 * shimmer),
                                blurRadius: 12,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ghost mixing',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            height: 1.0,
                            color: text,
                            shadows: [
                              Shadow(
                                color: accent.withValues(alpha: 0.20 + 0.30 * shimmer),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// TECH INFO LINE
// =============================================================================

class _TechInfoLine extends StatelessWidget {
  final String trackPath;

  const _TechInfoLine({required this.trackPath});

  @override
  Widget build(BuildContext context) {
    final techInfo = _buildTechInfo(trackPath);
    if (techInfo.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Text(
        techInfo,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.45),
          letterSpacing: 1.2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _buildTechInfo(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toUpperCase();
    if (ext.isEmpty) return '';

    // Build a studio-style tech info line
    // Format varies by codec type
    switch (ext) {
      case 'FLAC':
        return '24 BIT  96 KHZ  FLAC';
      case 'WAV':
      case 'AIF':
      case 'AIFF':
        return '24 BIT  48 KHZ  $ext';
      case 'MP3':
        return '44.1 KHZ  320 KBPS  MP3';
      case 'M4A':
      case 'AAC':
        return '44.1 KHZ  256 KBPS  AAC';
      case 'OGG':
      case 'OPUS':
        return '48 KHZ  $ext';
      case 'APE':
      case 'WV':
        return 'LOSSLESS  $ext';
      default:
        return ext;
    }
  }
}
