import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:ghostmusic/domain/models/track.dart';
import 'package:ghostmusic/domain/services/cover_art_service.dart';
import 'package:ghostmusic/domain/services/metadata_service.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';

final coverPickerMetaProvider = FutureProvider.family<TrackMetadataResult, String>((ref, trackPath) async {
  return MetadataService.enrichTrack(Track(filePath: trackPath));
});

final coverPickerCandidatesProvider = FutureProvider.family<List<CoverCandidate>, String>((ref, trackPath) async {
  final meta = await ref.watch(coverPickerMetaProvider(trackPath).future);

  final artist = meta.track.artist;
  final album = meta.track.album;

  // If we have both artist and album, search with them
  if (artist != null && artist.trim().isNotEmpty && album != null && album.trim().isNotEmpty) {
    return CoverArtService.searchCandidates(artist: artist, album: album);
  }

  // If only artist and title, try search by track title
  final title = meta.track.title;
  if (artist != null && artist.trim().isNotEmpty && title != null && title.trim().isNotEmpty) {
    return CoverArtService.searchByTrackTitle(artist: artist, title: title);
  }

  return const [];
});

// Custom search provider
final customSearchProvider = FutureProvider.family<List<CoverCandidate>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  return CoverArtService.searchCustom(query);
});

class CoverPickerSheet {
  static Future<void> show(BuildContext context, String trackPath) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _CoverPickerContent(
          trackPath: trackPath,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _CoverPickerContent extends ConsumerStatefulWidget {
  final String trackPath;
  final ScrollController scrollController;

  const _CoverPickerContent({
    required this.trackPath,
    required this.scrollController,
  });

  @override
  ConsumerState<_CoverPickerContent> createState() => _CoverPickerContentState();
}

class _CoverPickerContentState extends ConsumerState<_CoverPickerContent> {
  final TextEditingController _searchController = TextEditingController();
  String? _customQuery;
  bool _isSearching = false;
  List<CoverCandidate>? _customResults;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performCustomSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _customQuery = query;
      _searchError = null;
    });

    try {
      final results = await CoverArtService.searchCustom(query);
      if (mounted) {
        setState(() {
          _customResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  void _clearCustomSearch() {
    setState(() {
      _customQuery = null;
      _customResults = null;
      _searchError = null;
      _searchController.clear();
    });
  }

  Future<void> _pickCoverFromFile() async {
    bool didShowDialog = false;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        dialogTitle: 'Выберите обложку',
        lockParentWindow: true,
      );

      final path = result?.files.single.path;
      if (path == null || path.trim().isEmpty) return;

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Сохранение обложки...'),
                ],
              ),
            ),
          ),
        ),
      );
      didShowDialog = true;

      final saved = await CoverArtService.saveCustomCoverFromFile(
        trackPath: widget.trackPath,
        imagePath: path,
      );

      if (!mounted) return;
      if (didShowDialog) Navigator.of(context).pop();

      if (saved == null) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Не удалось установить обложку из файла'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      ref.invalidate(trackArtworkPathProvider(widget.trackPath));

      navigator.pop(); // Close picker sheet
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Обложка установлена (файл)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (didShowDialog) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metaAsync = ref.watch(coverPickerMetaProvider(widget.trackPath));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Icon(Icons.image_search_rounded, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выбор обложки',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    metaAsync.whenData((meta) {
                      return Text(
                        meta.track.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      );
                    }).value ?? const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Custom Search Field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Свой поиск: артист, альбом, обложка...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _customQuery != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _clearCustomSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performCustomSearch(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSearching ? null : _performCustomSearch,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search_rounded),
              ),
            ],
          ),
        ),

        // Results area
        Expanded(
          child: _customQuery != null
              ? _buildCustomResults()
              : _buildAutoResults(),
        ),

        // Bottom buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: metaAsync.when(
            data: (meta) {
              final artist = meta.track.artist?.trim();
              final album = meta.track.album?.trim();
              final hasValidTags = artist != null && artist.isNotEmpty && album != null && album.isNotEmpty;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: !hasValidTags
                              ? null
                              : () async {
                                  await CoverArtService.clearOverrideByArtistAlbum(
                                    artist: artist,
                                    album: album,
                                  );
                                  ref.invalidate(trackArtworkPathProvider(widget.trackPath));
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Обложка сброшена')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.restore_rounded),
                          label: const Text('Сбросить'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ref.invalidate(coverPickerCandidatesProvider(widget.trackPath));
                            _clearCustomSearch();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Обновить'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _pickCoverFromFile,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Выбрать файл…'),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomResults() {
    final cs = Theme.of(context).colorScheme;

    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Поиск изображений...'),
          ],
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Ошибка поиска', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_searchError!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final results = _customResults ?? [];
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Ничего не найдено',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 4),
            Text(
              'Попробуйте другой запрос',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return _buildCandidatesGrid(results);
  }

  Widget _buildAutoResults() {
    final candidatesAsync = ref.watch(coverPickerCandidatesProvider(widget.trackPath));
    final metaAsync = ref.watch(coverPickerMetaProvider(widget.trackPath));
    final cs = Theme.of(context).colorScheme;

    return candidatesAsync.when(
      data: (candidates) {
        if (candidates.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Автопоиск не нашёл обложек',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  metaAsync.whenData((meta) {
                    final artist = meta.track.artist?.trim();
                    final album = meta.track.album?.trim();
                    if (artist == null || artist.isEmpty || album == null || album.isEmpty) {
                      return Text(
                        'Заполните теги (Artist/Album) для лучших результатов',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
                      );
                    }
                    return const SizedBox.shrink();
                  }).value ?? const SizedBox.shrink(),
                  const SizedBox(height: 16),
                  Text(
                    'Используйте поиск выше',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Найдено автоматически: ${candidates.length}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildCandidatesGrid(candidates)),
          ],
        );
      },
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Поиск обложек...'),
          ],
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Ошибка поиска: $e', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidatesGrid(List<CoverCandidate> candidates) {
    return GridView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final c = candidates[index];
        return _CandidateTile(
          candidate: c,
          onPick: () => _saveCover(c),
        );
      },
    );
  }

  Future<void> _saveCover(CoverCandidate candidate) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Сохранение обложки...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Try to save using the new custom cover method
      final saved = await CoverArtService.saveCustomCover(
        trackPath: widget.trackPath,
        imageUrl: candidate.imageUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (saved == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Не удалось скачать обложку (${candidate.provider})'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      ref.invalidate(trackArtworkPathProvider(widget.trackPath));

      if (mounted) {
        navigator.pop(); // Close picker sheet
        messenger.showSnackBar(
          SnackBar(
            content: Text('Обложка установлена (${candidate.provider})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _CandidateTile extends StatefulWidget {
  final CoverCandidate candidate;
  final VoidCallback onPick;

  const _CandidateTile({required this.candidate, required this.onPick});

  @override
  State<_CandidateTile> createState() => _CandidateTileState();
}

class _CandidateTileState extends State<_CandidateTile> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPick();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Image.network(
              widget.candidate.previewUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  if (_isLoading) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _isLoading = false);
                    });
                  }
                  return child;
                }
                return Container(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) {
                if (!_hasError) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _hasError = true);
                  });
                }
                return Container(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined, color: cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(height: 4),
                      Text(
                        'Ошибка',
                        style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Provider label
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.candidate.provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Selection overlay on tap
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onPick();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
