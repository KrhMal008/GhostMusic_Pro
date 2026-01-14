import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';

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

  // оставляем на будущее (если вернёшь скролл/лирикс)
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _artworkIntroController = AnimationController(
      vsync: this,
      duration: AppDuration.slow,
    );
    _artworkScaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
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
    _contentScrollController.dispose();
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

  bool _canStartDismissDrag() {
    // Сейчас контент НЕ скроллится, так что это всегда true.
    // Оставлено для будущего, если вернёшь скролл.
    if (!_contentScrollController.hasClients) return true;
    return _contentScrollController.offset <= 0.0;
  }

  void _startDragIfPossible() {
    if (!_canStartDismissDrag()) return;

    if (_dismissController.isAnimating) {
      _dragOffset = _dragOffsetAnim.value;
      _dismissController.stop();
      _dragOffsetAnim = AlwaysStoppedAnimation(_dragOffset);
    }
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    if (_isDraggingSeek) return; // когда тянут слайдер — не закрываем панель

    final dy = details.delta.dy;

    // закрываем только движением ВНИЗ
    if (dy <= 0) return;

    _startDragIfPossible();

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
                    title: const Text('Обложка…'),
                    subtitle: const Text('Выбрать/подгрузить обложку'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      CoverPickerSheet.show(context, trackPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Редактировать теги…'),
                    subtitle: const Text('Artist / Album для поиска обложек'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      TagEditorSheet.show(context, trackPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_rounded),
                    title: const Text('Перенести/копировать…'),
                    subtitle: const Text('В папку на диске'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openMoveCopy(trackPath);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Пересканировать обложку'),
                    subtitle: const Text('Очистить кэш и попробовать снова'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await CoverArtService.clearNetCacheForFile(trackPath);
                        await CoverArtService.getOrFetchForFile(trackPath);
                      } catch (_) {}

                      if (!mounted) return;
                      ref.invalidate(trackArtworkPathProvider(trackPath));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Повторный поиск обложки запущен')),
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
                    title: const Text('Копировать в папку…'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _moveOrCopyToFolder(trackPath, move: false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.drive_file_move_rounded),
                    title: const Text('Перенести в папку…'),
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
          content: Text(move ? 'Перемещено в: $destinationFolder' : 'Скопировано в: $destinationFolder'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось ${move ? 'переместить' : 'скопировать'}: $e')),
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
                    title: const Text('Выбрать другую папку…'),
                    subtitle: const Text('Через системный диалог'),
                    onTap: () async {
                      final picked = await FilePicker.platform.getDirectoryPath(
                        dialogTitle: 'Выберите папку',
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
    if (!await src.exists()) throw Exception('Файл не найден');

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
      if (n > 999) throw Exception('Слишком много файлов с одинаковым именем');
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
        final scale = lerpDouble(1.0, 0.965, t)!;

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
            const Positioned.fill(child: ColoredBox(color: Colors.black)),

            // blurred bg
            Positioned.fill(
              child: RepaintBoundary(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: _AnimatedBackground(artworkAsync: artworkAsync),
                ),
              ),
            ),

            const Positioned.fill(child: _VignetteOverlay()),
            const Positioned.fill(child: _NoiseOverlay(opacity: 0.035)),

            // IMPORTANT:
            // Весь экран ловит drag-to-dismiss (как “панель”, а не отдельная обложка)
            // Но мы разрешаем только swipe DOWN (это уже проверено в _onDismissDragUpdate)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: _onDismissDragUpdate,
                onVerticalDragEnd: _onDismissDragEnd,
                child: Column(
                  children: [
                    SizedBox(height: topPadding),

                    _Header(
                      onClose: _close,
                      onOpenQueue: state.hasQueue ? _openQueue : null,
                      onOpenMore: track == null ? null : () => _openMore(track.filePath),
                      // можно оставить: хедер тоже отдельно ловит
                      onDragUpdate: _onDismissDragUpdate,
                      onDragEnd: _onDismissDragEnd,
                    ),

                    Expanded(
                      child: track == null
                          ? const _EmptyState()
                          : _PlayerContent(
                              state: state,
                              artworkScale: _artworkScaleAnimation,

                              // НИКАКОГО SingleChildScrollView -> не листается “как браузер”
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
                              onOpenQueue: state.hasQueue ? _openQueue : null,
                              onOpenEqualizer: _openEqualizer,
                              onOpenMore: track == null ? null : () => _openMore(track.filePath),
                            ),
                    ),

                    if (track != null)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: bottomPadding + 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SecondaryControls(
                              shuffleEnabled: state.shuffleEnabled,
                              repeatMode: state.repeatMode,
                              onShuffle: () => ctrl.toggleShuffle(),
                              onRepeat: () => ctrl.toggleRepeat(),
                              onOpenQueue: state.hasQueue ? _openQueue : null,
                              onOpenEqualizer: _openEqualizer,
                            ),
                            const SizedBox(height: 16),
                            _TechInfo(trackPath: track.filePath),
                          ],
                        ),
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

class _AnimatedBackground extends StatelessWidget {
  final AsyncValue<String?> artworkAsync;

  const _AnimatedBackground({required this.artworkAsync});

  @override
  Widget build(BuildContext context) {
    return artworkAsync.when(
      data: (path) {
        if (path == null) return const _GradientBackground();
        return AnimatedSwitcher(
          duration: AppDuration.smooth,
          child: Image.file(
            File(path),
            key: ValueKey(path),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const _GradientBackground(),
          ),
        );
      },
      loading: () => const _GradientBackground(),
      error: (_, __) => const _GradientBackground(),
    );
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.playerBackground(cs.primary)),
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
            center: const Alignment(0.0, -0.2),
            radius: 1.2,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.60),
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
    for (var i = 0; i < 900; i++) {
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
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const GlassHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  color: cs.onSurface,
                  tooltip: 'Close',
                ),
                const Spacer(),
                if (onOpenQueue != null)
                  IconButton(
                    onPressed: onOpenQueue,
                    icon: const Icon(Icons.queue_music_rounded, size: 26),
                    color: cs.onSurface.withValues(alpha: 0.85),
                    tooltip: 'Queue',
                  ),
                IconButton(
                  onPressed: onOpenMore,
                  icon: const Icon(Icons.more_horiz_rounded, size: 26),
                  color: cs.onSurface.withValues(alpha: 0.85),
                  tooltip: 'Ещё',
                ),
              ],
            ),
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
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_rounded, size: 64, color: cs.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            'Nothing Playing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a track from your library',
            style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

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
    this.onOpenQueue,
    this.onOpenEqualizer,
    this.onOpenMore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final track = state.currentTrack!;
    final seekValue = isDraggingSeek ? dragSeekValue : state.progress01;

    final index = state.currentIndex;
    final total = state.queue.length;
    final queuePosition = (index != null && total > 0) ? '${index + 1} / $total' : null;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Обложка больше не в скролле — ощущается частью панели
              ScaleTransition(
                scale: artworkScale,
                child: _ArtworkContainer(trackPath: track.filePath),
              ),

              const SizedBox(height: 18),

              if (queuePosition != null) ...[
                Center(
                  child: Text(
                    queuePosition,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.55),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              _TrackDetails(
                title: track.displayTitle,
                artist: track.artist,
                album: track.album,
                onMore: onOpenMore,
              ),

              const SizedBox(height: 14),

              _SeekBar(
                value: seekValue,
                position: state.position,
                duration: state.duration,
                isDragging: isDraggingSeek,
                onChangeStart: onSeekStart,
                onChanged: onSeekUpdate,
                onChangeEnd: onSeekEnd,
              ),

              _GhostMixingIndicator(
                phase: state.mixPhase,
                progress01: state.mixProgress01,
              ),

              const SizedBox(height: 20),

              _PlaybackControls(
                isPlaying: state.isPlaying,
                onPlayPause: onPlayPause,
                onNext: onNext,
                onPrevious: onPrevious,
              ),

              const SizedBox(height: 18),

              if (onOpenQueue != null || onOpenEqualizer != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: GlassSurface.chip(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onOpenEqualizer != null) ...[
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onOpenEqualizer?.call();
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.82)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'EQ',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.82),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (onOpenEqualizer != null && onOpenQueue != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Container(width: 1, height: 18, color: cs.onSurface.withValues(alpha: 0.10)),
                            ),
                          if (onOpenQueue != null) ...[
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onOpenQueue?.call();
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.queue_music_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.82)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Queue',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.82),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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

class _ArtworkContainer extends StatelessWidget {
  final String trackPath;

  const _ArtworkContainer({required this.trackPath});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final glow = cs.primary.withValues(alpha: 0.24);

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [glow, Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.artworkLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.artworkLarge),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TrackArtwork(
                      trackPath: trackPath,
                      size: double.infinity,
                      radius: AppRadius.artworkLarge,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.artworkLarge),
                        border: Border.all(
                          color: cs.onSurface.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.artworkLarge),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.10),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackDetails extends StatelessWidget {
  final String title;
  final String? artist;
  final String? album;
  final VoidCallback? onMore;

  const _TrackDetails({
    required this.title,
    this.artist,
    this.album,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final artistText = artist?.trim();
    final albumText = album?.trim();

    final subtitleParts = <String>[];
    if (artistText != null && artistText.isNotEmpty) subtitleParts.add(artistText);
    if (albumText != null && albumText.isNotEmpty && albumText != artistText) subtitleParts.add(albumText);

    final subtitle = subtitleParts.isEmpty ? null : subtitleParts.join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.62),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onMore != null)
          IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              onMore?.call();
            },
            icon: const Icon(Icons.more_horiz_rounded),
            color: cs.onSurface.withValues(alpha: 0.85),
            tooltip: 'Ещё',
          ),
      ],
    );
  }
}

class _SeekBar extends StatelessWidget {
  final double value;
  final Duration position;
  final Duration? duration;
  final bool isDragging;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SeekBar({
    required this.value,
    required this.position,
    required this.duration,
    required this.isDragging,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = duration;

    final clampedPosition = d == null
        ? position
        : Duration(milliseconds: position.inMilliseconds.clamp(0, d.inMilliseconds));

    var remaining = d == null ? null : (d - clampedPosition);
    if (remaining != null && remaining.isNegative) remaining = Duration.zero;

    final thumbRadius = isDragging ? 7.0 : 0.0;
    final overlayRadius = isDragging ? 16.0 : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: thumbRadius),
            overlayShape: RoundSliderOverlayShape(overlayRadius: overlayRadius),
            activeTrackColor: cs.onSurface.withValues(alpha: 0.92),
            inactiveTrackColor: cs.onSurface.withValues(alpha: 0.18),
            thumbColor: cs.onSurface.withValues(alpha: 0.92),
            overlayColor: cs.onSurface.withValues(alpha: 0.10),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChangeStart: d != null ? onChangeStart : null,
            onChanged: d != null ? onChanged : null,
            onChangeEnd: d != null ? onChangeEnd : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(clampedPosition),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                remaining != null ? '-${_formatDuration(remaining)}' : '--:--',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

// ---- ниже: индикатор микса + контролы ----
// Если у тебя в проекте эта часть уже есть в других файлах — оставляй как есть.
// Здесь — рабочая версия, без обрывов.

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
    if (widget.phase == MixPhase.off) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;

    final shimmer = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
    final progress = widget.phase == MixPhase.mixing ? widget.progress01.clamp(0.0, 1.0) : 0.0;

    final bg = Color.lerp(accent.withValues(alpha: 0.08), accent.withValues(alpha: 0.14), shimmer)!;
    final border = Color.lerp(accent.withValues(alpha: 0.16), accent.withValues(alpha: 0.26), shimmer)!;
    final text = Color.lerp(cs.onSurface.withValues(alpha: 0.60), accent.withValues(alpha: 0.95), shimmer)!;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
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
                    _MixDot(color: accent, shimmer: shimmer),
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
  }
}

class _MixDot extends StatelessWidget {
  final Color color;
  final double shimmer;

  const _MixDot({required this.color, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final alpha = (0.45 + 0.45 * shimmer).clamp(0.0, 1.0);
    final shadowAlpha = (0.18 + 0.35 * shimmer).clamp(0.0, 1.0);

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: shadowAlpha),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const _PlaybackControls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onPrevious();
          },
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 34,
          color: cs.onSurface.withValues(alpha: 0.90),
        ),
        const SizedBox(width: 18),
        _PlayPauseButton(isPlaying: isPlaying, onPressed: onPlayPause),
        const SizedBox(width: 18),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onNext();
          },
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 34,
          color: cs.onSurface.withValues(alpha: 0.90),
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 44,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TechInfo extends StatelessWidget {
  final String trackPath;

  const _TechInfo({required this.trackPath});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final ext = p.extension(trackPath).replaceFirst('.', '').toUpperCase();
    if (ext.trim().isEmpty) return const SizedBox.shrink();

    return Center(
      child: Text(
        ext,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.45),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SecondaryControls extends StatelessWidget {
  final bool shuffleEnabled;

  /// ВАЖНО: не RepeatMode — чтобы не зависеть от твоих моделей.
  /// Может прийти int/bool/String/enum — мы всё переварим.
  final Object repeatMode;

  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenEqualizer;

  const _SecondaryControls({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.onShuffle,
    required this.onRepeat,
    this.onOpenQueue,
    this.onOpenEqualizer,
  });

  int _repeatIndex(Object mode) {
    // 0 = off, 1 = all, 2 = one

    // Самый частый вариант: int
    if (mode is int) {
      if (mode <= 0) return 0;
      if (mode == 2) return 2;
      return 1;
    }

    // Иногда делают bool: false=off true=all
    if (mode is bool) return mode ? 1 : 0;

    // Иногда строками
    if (mode is String) {
      final v = mode.toLowerCase().trim();
      if (v == 'off' || v == 'none' || v == '0') return 0;
      if (v == 'one' || v == 'repeat_one' || v == 'single' || v == '2') return 2;
      return 1;
    }

    // Если это enum/объект — пробуем вытащить .name (Dart enum имеет name)
    try {
      final name = (mode as dynamic).name?.toString().toLowerCase();
      if (name == null) return 0;
      if (name.contains('off') || name.contains('none')) return 0;
      if (name.contains('one') || name.contains('single')) return 2;
      // всё остальное считаем "repeat all"
      return 1;
    } catch (_) {
      // на крайняк — считаем выключенным
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final idx = _repeatIndex(repeatMode);
    final repeatIsActive = idx != 0;
    final repeatIcon = (idx == 2) ? Icons.repeat_one_rounded : Icons.repeat_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SmallToggleButton(
          icon: Icons.shuffle_rounded,
          active: shuffleEnabled,
          onTap: onShuffle,
          activeColor: cs.primary,
        ),
        const SizedBox(width: 14),
        _SmallToggleButton(
          icon: repeatIcon,
          active: repeatIsActive,
          onTap: onRepeat,
          activeColor: cs.primary,
        ),
        const SizedBox(width: 14),
        _SmallToggleButton(
          icon: Icons.tune_rounded,
          active: false,
          onTap: onOpenEqualizer,
          activeColor: cs.primary,
        ),
        const SizedBox(width: 14),
        _SmallToggleButton(
          icon: Icons.queue_music_rounded,
          active: false,
          onTap: onOpenQueue,
          activeColor: cs.primary,
        ),
      ],
    );
  }
}


class _SmallToggleButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final Color activeColor;

  const _SmallToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final enabled = onTap != null;
    final iconColor = active
        ? activeColor
        : enabled
            ? cs.onSurface.withValues(alpha: 0.75)
            : cs.onSurface.withValues(alpha: 0.35);

    final bg = active ? activeColor.withValues(alpha: 0.14) : Colors.transparent;

    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap?.call();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24, color: iconColor),
      ),
    );
  }
}
