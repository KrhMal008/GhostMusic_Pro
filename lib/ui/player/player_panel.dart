// player_panel.dart
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

class _PlayerPanelState extends ConsumerState<PlayerPanel> with TickerProviderStateMixin {
  bool _isDraggingSeek = false;
  double _dragSeekValue = 0.0;

  // Drag-to-dismiss
  double _dragOffset = 0.0;
  late final AnimationController _dismissAnimController;
  late Animation<double> _dragOffsetAnim;

  late final AnimationController _artworkAnimController;
  late final Animation<double> _artworkScaleAnimation;

  // Scroll controller (pull-to-dismiss from content)
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _artworkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _artworkScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _artworkAnimController,
        curve: Curves.easeOutCubic,
      ),
    );

    _artworkAnimController.forward();

    _dismissAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _dragOffsetAnim = AlwaysStoppedAnimation(_dragOffset);

    _dismissAnimController.addListener(() {
      if (!mounted) return;
      setState(() {
        _dragOffset = _dragOffsetAnim.value;
      });
    });
  }

  @override
  void dispose() {
    _artworkAnimController.dispose();
    _dismissAnimController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  void _close() {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
  }

  // ===== Header drag (ручка/хедер) =====
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy <= 0) return;

    if (_dismissAnimController.isAnimating) {
      _dismissAnimController.stop();
    }

    final maxDrag = MediaQuery.of(context).size.height * 0.75;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, maxDrag);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    const dismissThreshold = 120.0;
    const dismissVelocity = 900.0;

    final vy = details.velocity.pixelsPerSecond.dy;
    final shouldDismiss = _dragOffset > dismissThreshold || vy > dismissVelocity;

    if (shouldDismiss) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    _animateBackToZero();
  }

  // ===== Pull-to-dismiss из контента (обложка/scroll) =====
  bool _onScrollNotification(ScrollNotification notification) {
    // Ключ: когда контент уже вверху (pixels <= 0),
    // и пользователь тянет вниз (scrollDelta < 0),
    // мы копим _dragOffset и двигаем весь экран.
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;

      final isAtTop = notification.metrics.pixels <= 0.0;
      final isPullingDown = delta < 0.0;

      if (isAtTop && isPullingDown) {
        if (_dismissAnimController.isAnimating) {
          _dismissAnimController.stop();
        }

        final pull = -delta; // делаем положительным
        final maxDrag = MediaQuery.of(context).size.height * 0.75;

        setState(() {
          _dragOffset = (_dragOffset + pull).clamp(0.0, maxDrag);
        });
      } else if (_dragOffset > 0 && delta > 0) {
        // если пользователь начал двигать обратно вверх — уменьшаем dragOffset
        setState(() {
          _dragOffset = (_dragOffset - delta).clamp(0.0, double.infinity);
        });
      }
    }

    if (notification is OverscrollNotification) {
      // На некоторых платформах overscroll может помогать добрать жест.
      // overscroll < 0 означает "тянем вниз".
      if (notification.overscroll < 0) {
        if (_dismissAnimController.isAnimating) {
          _dismissAnimController.stop();
        }

        final pull = -notification.overscroll;
        final maxDrag = MediaQuery.of(context).size.height * 0.75;

        setState(() {
          _dragOffset = (_dragOffset + pull).clamp(0.0, maxDrag);
        });
      }
    }

    if (notification is ScrollEndNotification) {
      if (_dragOffset > 0) {
        final velocity = notification.dragDetails?.velocity ?? Velocity.zero;
        _finalizeDismiss(velocity);
      }
    }

    return false;
  }

  void _finalizeDismiss(Velocity velocity) {
    // Более “apple-like” пороги
    const dismissThreshold = 70.0;
    const dismissVelocity = 650.0;

    final vy = velocity.pixelsPerSecond.dy;
    final shouldDismiss = _dragOffset > dismissThreshold || vy > dismissVelocity;

    if (shouldDismiss) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
      return;
    }

    _animateBackToZero();
  }

  void _animateBackToZero() {
    _dragOffsetAnim = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(
        parent: _dismissAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _dismissAnimController.forward(from: 0.0);
  }

  void _openQueue() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
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
                      if (mounted) {
                        ref.invalidate(trackArtworkPathProvider(trackPath));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Повторный поиск обложки запущен')),
                        );
                      }
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

        if (wasPlaying) {
          await ctrl.togglePlayPause();
        }

        final updatedQueue = playback.queue
            .map((t) => t.filePath == trackPath ? t.copyWith(filePath: newPath) : t)
            .toList(growable: false);

        await ctrl.setQueue(updatedQueue, startIndex: currentIndex, autoplay: false);
        await ctrl.seek(pos);

        if (wasPlaying) {
          await ctrl.togglePlayPause();
        }
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
                      subtitle: Text(
                        f,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
    if (!await src.exists()) {
      throw Exception('Файл не найден');
    }

    final targetDir = Directory(destDir);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

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
      if (n > 999) {
        throw Exception('Слишком много файлов с одинаковым именем');
      }
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
    final artworkPath = track != null
        ? ref.watch(trackArtworkPathProvider(track.filePath))
        : const AsyncValue<String?>.data(null);

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return AnimatedBuilder(
      animation: _dismissAnimController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _dragOffset),
          child: child,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.black)),
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: _AnimatedBackground(artworkAsync: artworkPath),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.74)),
            ),
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: topPadding),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: _Header(
                      onClose: _close,
                      onOpenQueue: state.hasQueue ? _openQueue : null,
                      onOpenMore: track == null ? null : () => _openMore(track.filePath),
                    ),
                  ),
                  Expanded(
                    child: track == null
                        ? const _EmptyState()
                        : NotificationListener<ScrollNotification>(
                            onNotification: _onScrollNotification,
                            child: _PlayerContent(
                              state: state,
                              artworkPath: artworkPath,
                              artworkAnimation: _artworkScaleAnimation,
                              isDraggingSeek: _isDraggingSeek,
                              dragSeekValue: _dragSeekValue,
                              scrollController: _contentScrollController,
                              onSeekStart: (value) {
                                setState(() {
                                  _isDraggingSeek = true;
                                  _dragSeekValue = value;
                                });
                              },
                              onSeekUpdate: (value) {
                                setState(() => _dragSeekValue = value);
                              },
                              onSeekEnd: (value) async {
                                final duration = state.duration;
                                if (duration != null) {
                                  final seekMs = (duration.inMilliseconds * value).round();
                                  await ctrl.seek(Duration(milliseconds: seekMs));
                                }
                                if (mounted) {
                                  setState(() => _isDraggingSeek = false);
                                }
                              },
                              onPlayPause: () => ctrl.togglePlayPause(),
                              onNext: () => ctrl.next(),
                              onPrevious: () => ctrl.previous(),
                              onShuffle: () => ctrl.toggleShuffle(),
                              onRepeat: () => ctrl.toggleRepeat(),
                              onOpenQueue: state.hasQueue ? _openQueue : null,
                              onOpenEqualizer: _openEqualizer,
                              onOpenMore: track == null ? null : () => _openMore(track.filePath),
                            ),
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
          duration: const Duration(milliseconds: 500),
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
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.playerBackground(cs.primary),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenMore;

  const _Header({
    required this.onClose,
    this.onOpenQueue,
    this.onOpenMore,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
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
          Icon(
            Icons.music_off_rounded,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.25),
          ),
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
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerContent extends StatelessWidget {
  final PlaybackState state;
  final AsyncValue<String?> artworkPath;
  final Animation<double> artworkAnimation;

  final bool isDraggingSeek;
  final double dragSeekValue;

  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;

  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenEqualizer;
  final VoidCallback? onOpenMore;

  final ScrollController? scrollController;

  const _PlayerContent({
    required this.state,
    required this.artworkPath,
    required this.artworkAnimation,
    required this.isDraggingSeek,
    required this.dragSeekValue,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onRepeat,
    this.onOpenQueue,
    this.onOpenEqualizer,
    this.onOpenMore,
    this.scrollController,
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
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              ScaleTransition(
                scale: artworkAnimation,
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

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: TrackArtwork(
                  trackPath: trackPath,
                  size: double.infinity,
                  radius: 20,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cs.onSurface.withValues(alpha: 0.10),
                      width: 0.5,
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
    if (albumText != null && albumText.isNotEmpty && albumText != artistText) {
      subtitleParts.add(albumText);
    }

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

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

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
    if (widget.phase != MixPhase.off) {
      _controller.repeat();
    }
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

    final bg = Color.lerp(
      accent.withValues(alpha: 0.08),
      accent.withValues(alpha: 0.14),
      shimmer,
    )!;

    final border = Color.lerp(
      accent.withValues(alpha: 0.16),
      accent.withValues(alpha: 0.26),
      shimmer,
    )!;

    final text = Color.lerp(
      cs.onSurface.withValues(alpha: 0.60),
      accent.withValues(alpha: 0.95),
      shimmer,
    )!;

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
                    _MixDot(
                      color: accent,
                      shimmer: shimmer,
                      phase: widget.phase,
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
                            color: accent.withValues(alpha: 0.25 + 0.35 * shimmer),
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
  final MixPhase phase;

  const _MixDot({
    required this.color,
    required this.shimmer,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final t = phase == MixPhase.mixing ? 1.0 : 0.6;

    final alpha = (0.45 + 0.45 * shimmer) * t;
    final shadowAlpha = (0.20 + 0.35 * shimmer) * t;

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha.clamp(0.0, 1.0)),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: shadowAlpha.clamp(0.0, 1.0)),
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

    return IconTheme(
      data: IconThemeData(color: cs.onSurface),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            size: 56,
            iconSize: 36,
            onPressed: onPrevious,
          ),
          const SizedBox(width: 16),
          _PlayPauseMainButton(
            isPlaying: isPlaying,
            onPressed: onPlayPause,
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: Icons.skip_next_rounded,
            size: 56,
            iconSize: 36,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _PlayPauseMainButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayPauseMainButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<_PlayPauseMainButton> createState() => _PlayPauseMainButtonState();
}

class _PlayPauseMainButtonState extends State<_PlayPauseMainButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
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
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onPressed,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> with SingleTickerProviderStateMixin {
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
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: cs.onSurface,
          ),
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
  final int repeatMode;
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

  @override
  Widget build(BuildContext context) {
    final repeatIcon = switch (repeatMode) {
      1 => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SecondaryButton(
          icon: Icons.shuffle_rounded,
          isActive: shuffleEnabled,
          onPressed: onShuffle,
          tooltip: 'Перемешать',
        ),
        const SizedBox(width: 14),
        _SecondaryButton(
          icon: repeatIcon,
          isActive: repeatMode != 0,
          onPressed: onRepeat,
          tooltip: 'Повтор',
        ),
        const SizedBox(width: 14),
        _SecondaryButton(
          icon: Icons.tune_rounded,
          isActive: false,
          onPressed: onOpenEqualizer,
          tooltip: 'Эквалайзер',
        ),
        const SizedBox(width: 14),
        _SecondaryButton(
          icon: Icons.queue_music_rounded,
          isActive: false,
          onPressed: onOpenQueue,
          tooltip: 'Очередь',
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final String tooltip;

  const _SecondaryButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    final bgColor = isActive ? cs.primary.withValues(alpha: 0.15) : Colors.transparent;

    final iconColor = isActive
        ? cs.primary
        : (enabled ? cs.onSurface.withValues(alpha: 0.75) : cs.onSurface.withValues(alpha: 0.35));

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed?.call();
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
