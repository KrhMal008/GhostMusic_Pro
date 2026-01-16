import 'dart:io';
import 'dart:ui';


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:ghostmusic/domain/models/track.dart';
import 'package:ghostmusic/domain/services/folder_art_service.dart';
import 'package:ghostmusic/domain/state/library_controller.dart';
import 'package:ghostmusic/domain/state/library_state.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/ui/artwork/artwork_view.dart';
import 'package:ghostmusic/ui/artwork/folder_artwork.dart';
import 'package:ghostmusic/ui/library/folder_browser.dart';
import 'package:ghostmusic/ui/player/gesture_surface.dart';
import 'package:ghostmusic/ui/player/now_playing_route.dart';
import 'package:ghostmusic/ui/player/now_playing_poweramp/components/poweramp_track_menu.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_app_bar.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';


class LibraryTab extends ConsumerWidget {
  const LibraryTab({super.key});

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface.sheet(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.create_new_folder_rounded),
                    title: const Text('Добавить папку…'),
                    subtitle: const Text('Выбрать папку с музыкой'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _addFolder(context, ref);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: const Text('Папки'),
                    subtitle: const Text('Управление папками библиотеки'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LibraryFoldersScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh_rounded),
                    title: const Text('Пересканировать'),
                    subtitle: const Text('Обновить список треков'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(libraryControllerProvider.notifier).rescan();
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


  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку с музыкой',
      lockParentWindow: true,
    );

    if (path == null || path.trim().isEmpty) return;

    await ref.read(libraryControllerProvider.notifier).addFolder(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryControllerProvider);
    final cs = Theme.of(context).colorScheme;

    final width = MediaQuery.of(context).size.width;
    final hPad = ((width - 720) / 2).clamp(16.0, double.infinity);
    final contentPadding = EdgeInsets.symmetric(horizontal: hPad);

    final bottomOverlay =
        MediaQuery.paddingOf(context).bottom + AppHitTarget.tabBarHeight + AppHitTarget.miniPlayerHeight;

    return CustomScrollView(
      slivers: [
        GlassSliverAppBar.large(
          title: const Text('Медиатека'),
          actions: [
            IconButton(
              tooltip: 'Меню',
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => _openActions(context, ref),
            ),
            const SizedBox(width: 12),
          ],
        ),

        SliverPadding(
          padding: contentPadding,
          sliver: SliverToBoxAdapter(
            child: _AppleLibraryMenu(
              onFolders: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LibraryFoldersScreen()),
                );
              },
              onTracks: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LibraryTracksScreen()),
                );
              },
              onAlbums: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LibraryAlbumsScreen()),
                );
              },
              onArtists: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LibraryArtistsScreen()),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  'Недавно добавлено',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                const Spacer(),
                if (library.isScanning)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.favorite,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${library.scannedFiles}',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    '${library.tracks.length}',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: contentPadding,
          sliver: Consumer(
            builder: (context, ref, _) {
              final recentAsync = ref.watch(recentlyAddedCollectionsProvider);
              return recentAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 20),
                        child: Text(
                          library.folders.isEmpty
                              ? 'Добавь папку с музыкой через меню “…”'
                              : 'Недавно добавленные альбомы появятся здесь',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ),
                    );
                  }

                  return SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      // Square artwork (1:1) + ~50px for labels = 0.78 aspect ratio
                      childAspectRatio: 0.78,
                    ),
                    itemCount: items.length.clamp(0, 8),
                    itemBuilder: (context, index) => _RecentCollectionTile(item: items[index]),
                  );
                },
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 18),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: cs.favorite),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Собираю “Недавно добавлено”…',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 18),
                    child: Text(
                      'Ошибка: $e',
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (library.lastError != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Ошибка сканирования: ${library.lastError}',
                style: TextStyle(color: cs.error),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: bottomOverlay + 24),
        ),
      ],
    );
  }
}

class _AppleLibraryMenu extends StatelessWidget {
  final VoidCallback onFolders;
  final VoidCallback onTracks;
  final VoidCallback onAlbums;
  final VoidCallback onArtists;

  const _AppleLibraryMenu({
    required this.onFolders,
    required this.onTracks,
    required this.onAlbums,
    required this.onArtists,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.favorite;

    Widget tile({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
      String? subtitle,
    }) {
      final enabled = onTap != null;
      final iconColor = enabled ? accent : cs.onSurface.withValues(alpha: 0.35);

      return TapScaleWrapper(
        onTap: onTap,
        enableHaptic: enabled,
        scaleDown: 0.985,
        duration: AppDuration.fastest,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  enabled ? Icons.chevron_right_rounded : Icons.lock_rounded,
                  color: cs.onSurface.withValues(alpha: enabled ? 0.35 : 0.25),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const dividerOpacity = 0.10;

    return Column(
      children: [
        tile(icon: Icons.library_music_rounded, label: 'Все треки', onTap: onTracks),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.folder_rounded, label: 'Папки', onTap: onFolders),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(
          icon: Icons.folder_copy_rounded,
          label: 'Папки (иерархия)',
          subtitle: 'Дерево папок',
          onTap: onFolders,
        ),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.album_rounded, label: 'Альбомы', onTap: onAlbums),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.person_rounded, label: 'Артисты', onTap: onArtists),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(
          icon: Icons.people_alt_rounded,
          label: 'Исполнители альбома',
          subtitle: 'Скоро',
          onTap: null,
        ),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.category_rounded, label: 'Жанры', subtitle: 'Скоро', onTap: null),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.calendar_month_rounded, label: 'Годы', subtitle: 'Скоро', onTap: null),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.edit_note_rounded, label: 'Композиторы', subtitle: 'Скоро', onTap: null),
        Divider(height: 1, color: cs.onSurface.withValues(alpha: dividerOpacity)),
        tile(icon: Icons.playlist_play_rounded, label: 'Плейлисты', subtitle: 'Скоро', onTap: null),
      ],
    );
  }
}

class _RecentCollectionTile extends ConsumerWidget {
  final RecentCollection item;

  const _RecentCollectionTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        if (item.tracks.isEmpty) return;

        try {
          await ref
              .read(playbackControllerProvider.notifier)
              .setQueue(item.tracks, startIndex: 0, autoplay: true);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Play failed: $e')),
            );
          }
          return;
        }

        if (!context.mounted) return;
        await NowPlayingRoute.open(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Square artwork with AspectRatio to ensure 1:1
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: TrackArtwork(
                  trackPath: item.artworkTrackPath,
                  size: double.infinity,
                  radius: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class LibraryFoldersScreen extends ConsumerWidget {
  const LibraryFoldersScreen({super.key});

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();

    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку с музыкой',
      lockParentWindow: true,
    );

    if (path == null || path.trim().isEmpty) return;

    await ref.read(libraryControllerProvider.notifier).addFolder(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final cs = Theme.of(context).colorScheme;

    final folderCounts = <String, int>{
      for (final f in library.folders) f: 0,
    };

    final folderPreview = <String, List<Track>>{
      for (final f in library.folders) f: <Track>[],
    };

    if (library.folders.isNotEmpty && library.tracks.isNotEmpty) {
      final roots = library.folders;
      final rootsLower = roots.map((f) => p.normalize(f).toLowerCase()).toList(growable: false);

      for (final t in library.tracks) {
        final pathLower = p.normalize(t.filePath).toLowerCase();
        for (var i = 0; i < rootsLower.length; i++) {
          if (pathLower.startsWith(rootsLower[i])) {
            final root = roots[i];
            folderCounts[root] = (folderCounts[root] ?? 0) + 1;

            final list = folderPreview[root];
            if (list != null && list.length < 12) {
              list.add(t);
            }

            break;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            GlassSliverAppBar.large(
              title: const Text('Папки'),
              actions: [
                IconButton(
                  tooltip: 'Добавить папку',
                  icon: const Icon(Icons.create_new_folder_rounded),
                  onPressed: () => _addFolder(context, ref),
                ),
                IconButton(
                  tooltip: 'Пересканировать',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.read(libraryControllerProvider.notifier).rescan(),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ];
        },
        body: Center(

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: library.folders.length + (library.folders.isEmpty ? 1 : 0),
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: cs.onSurface.withValues(alpha: 0.08),
            ),
            itemBuilder: (context, index) {
              if (library.folders.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Папки не добавлены. Нажми “+” и выбери папку с музыкой.',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                );
              }

              final folder = library.folders[index];
              final count = folderCounts[folder] ?? 0;
              final name = p.basename(folder).isEmpty ? folder : p.basename(folder);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                leading: FolderArtwork(
                  folderPath: folder,
                  tracks: folderPreview[folder] ?? const <Track>[],
                  size: 44,
                  radius: 12,
                ),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassSurface.chip(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        count == 0 ? '—' : '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.35)),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FolderBrowserScreen(rootFolder: folder, folder: folder)),
                  );
                },
                onLongPress: () async {
                  HapticFeedback.mediumImpact();

                  await showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
                    builder: (ctx) {
                      final rootLower = p.normalize(folder).toLowerCase();
                      final folderTracks = library.tracks
                          .where((t) {
                            final dirLower = p.normalize(p.dirname(t.filePath)).toLowerCase();
                            return dirLower == rootLower || dirLower.startsWith(rootLower);
                          })
                          .toList(growable: false)
                        ..sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));

                      Future<void> setOverride(FolderArtOverride override) async {
                        await FolderArtService.setForFolder(folder, override);
                        ref.invalidate(folderArtOverrideProvider(folder));
                      }

                      Future<void> clearOverride() async {
                        await FolderArtService.clearForFolder(folder);
                        ref.invalidate(folderArtOverrideProvider(folder));
                      }

                      Future<String?> pickTrackCover() {
                        final items = folderTracks.take(160).toList(growable: false);

                        return showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
                          isScrollControlled: true,
                          builder: (tctx) {
                            final height = MediaQuery.sizeOf(tctx).height * 0.75;

                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: GlassSurface(
                                  variant: GlassVariant.solid,
                                  shape: GlassShape.roundedLarge,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: SizedBox(
                                    height: height,
                                    child: ListView.builder(
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        final t = items[index];
                                        return ListTile(
                                          leading: SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: TrackArtwork(
                                              trackPath: t.filePath,
                                              size: 44,
                                              radius: 10,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          title: Text(t.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          subtitle: Text(
                                            [t.artist, t.album]
                                                .whereType<String>()
                                                .where((s) => s.trim().isNotEmpty)
                                                .join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onTap: () => Navigator.of(tctx).pop(t.filePath),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }

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
                                  leading: const Icon(Icons.auto_awesome_rounded),
                                  title: const Text('Обложка: авто'),
                                  subtitle: const Text('Одна если одинаковая, иначе коллаж'),
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await clearOverride();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.grid_view_rounded),
                                  title: const Text('Обложка: коллаж'),
                                  subtitle: const Text('Всегда показывать коллаж'),
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await setOverride(const FolderArtOverride(mode: FolderArtMode.collage));
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.image_rounded),
                                  title: const Text('Обложка: картинка…'),
                                  subtitle: const Text('JPG/PNG/WebP'),
                                  onTap: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                                      lockParentWindow: true,
                                    );
                                    if (!ctx.mounted) return;
                                    Navigator.of(ctx).pop();
                                    final path = result?.files.single.path;
                                    if (path == null || path.trim().isEmpty) return;
                                    await setOverride(FolderArtOverride(mode: FolderArtMode.imageFile, value: path));
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.library_music_rounded),
                                  title: const Text('Обложка: из трека…'),
                                  subtitle: Text(
                                    folderTracks.isEmpty ? 'В папке нет треков' : 'Выбрать из треков папки',
                                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
                                  ),
                                  onTap: folderTracks.isEmpty
                                      ? null
                                      : () async {
                                          Navigator.of(ctx).pop();
                                          final selected = await pickTrackCover();
                                          if (selected == null || selected.trim().isEmpty) return;
                                          await setOverride(
                                            FolderArtOverride(mode: FolderArtMode.track, value: selected),
                                          );
                                        },
                                ),
                                Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.10)),
                                ListTile(
                                  leading: const Icon(Icons.delete_outline_rounded),
                                  title: const Text('Удалить папку из библиотеки'),
                                  subtitle: const Text('Файлы на диске не удаляются'),
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    await ref.read(libraryControllerProvider.notifier).removeFolder(folder);
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
                },
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

class LibraryTracksScreen extends ConsumerWidget {

  const LibraryTracksScreen({super.key});

  Future<void> _playFromLibrary(BuildContext context, WidgetRef ref, List<Track> tracks, int index) async {
    if (tracks.isEmpty) return;

    try {
      await ref.read(playbackControllerProvider.notifier).setQueue(tracks, startIndex: index, autoplay: true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
      }
      return;
    }

    if (!context.mounted) return;
    await NowPlayingRoute.open(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final playback = ref.watch(playbackControllerProvider);
    final cs = Theme.of(context).colorScheme;

    final tracks = library.tracks;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return const [
            GlassSliverAppBar.large(title: Text('Песни')),
          ];
        },
        body: Center(

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isCurrent = playback.currentTrack?.filePath == track.filePath;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: TrackArtwork(
                    trackPath: track.filePath,
                    size: 44,
                    radius: 10,
                  ),
                ),
                title: Text(track.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [track.artist, track.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: isCurrent && playback.isPlaying
                    ? Icon(Icons.equalizer_rounded, color: cs.favorite)
                    : Icon(Icons.more_horiz_rounded, color: cs.onSurface.withValues(alpha: 0.45)),
                onTap: () => _playFromLibrary(context, ref, tracks, index),
                onLongPress: () => PowerampTrackMenu.show(context, track.filePath),
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

class LibraryAlbumsScreen extends ConsumerWidget {

  const LibraryAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final cs = Theme.of(context).colorScheme;

    final items = _buildAlbumCollections(library.tracks);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return const [
            GlassSliverAppBar.large(title: Text('Альбомы')),
          ];
        },
        body: Center(

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: TrackArtwork(
                    trackPath: item.artworkTrackPath,
                    size: 44,
                    radius: 10,
                  ),
                ),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: GlassSurface.chip(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${item.tracks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _CollectionDetailScreen(
                        title: item.title,
                        subtitle: item.subtitle,
                        tracks: item.tracks,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

class LibraryArtistsScreen extends ConsumerWidget {

  const LibraryArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final cs = Theme.of(context).colorScheme;

    final items = _buildArtistCollections(library.tracks);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return const [
            GlassSliverAppBar.large(title: Text('Артисты')),
          ];
        },
        body: Center(

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: TrackArtwork(
                    trackPath: item.artworkTrackPath,
                    size: 44,
                    radius: 10,
                  ),
                ),
                title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                trailing: GlassSurface.chip(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${item.tracks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _CollectionDetailScreen(
                        title: item.title,
                        subtitle: item.subtitle,
                        tracks: item.tracks,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

class _CollectionItem {

  final String title;
  final String subtitle;
  final String artworkTrackPath;
  final List<Track> tracks;

  const _CollectionItem({
    required this.title,
    required this.subtitle,
    required this.artworkTrackPath,
    required this.tracks,
  });
}

List<_CollectionItem> _buildAlbumCollections(List<Track> tracks) {
  final groups = <String, List<Track>>{};

  for (final t in tracks) {
    final artist = (t.artist ?? '').trim();
    final album = (t.album ?? '').trim();

    final key = (album.isNotEmpty || artist.isNotEmpty)
        ? 'album|${artist.toLowerCase()}|${album.toLowerCase()}'
        : 'folder|${p.normalize(p.dirname(t.filePath)).toLowerCase()}';

    (groups[key] ??= <Track>[]).add(t);
  }

  final items = <_CollectionItem>[];

  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;

    final first = list.first;
    final artist = (first.artist ?? '').trim();
    final album = (first.album ?? '').trim();

    final title = album.isNotEmpty ? album : p.basename(p.dirname(first.filePath));
    final subtitle = artist.isNotEmpty ? artist : p.dirname(first.filePath);

    items.add(
      _CollectionItem(
        title: title,
        subtitle: subtitle,
        artworkTrackPath: first.filePath,
        tracks: list,
      ),
    );
  }

  items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return items;
}

List<_CollectionItem> _buildArtistCollections(List<Track> tracks) {
  final groups = <String, List<Track>>{};

  for (final t in tracks) {
    final artist = (t.artist ?? '').trim();
    final key = artist.isNotEmpty ? artist.toLowerCase() : '(unknown)';
    (groups[key] ??= <Track>[]).add(t);
  }

  final items = <_CollectionItem>[];

  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;

    final first = list.first;
    final artist = (first.artist ?? '').trim();

    final albumSet = <String>{};
    for (final t in list) {
      final a = (t.album ?? '').trim();
      if (a.isNotEmpty) albumSet.add(a.toLowerCase());
    }

    final title = artist.isNotEmpty ? artist : 'Unknown Artist';
    final subtitle = albumSet.isEmpty
        ? '${list.length} треков'
        : '${list.length} треков • ${albumSet.length} альбомов';

    items.add(
      _CollectionItem(
        title: title,
        subtitle: subtitle,
        artworkTrackPath: first.filePath,
        tracks: list,
      ),
    );
  }

  items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return items;
}

class _CollectionDetailScreen extends ConsumerWidget {
  final String title;
  final String subtitle;
  final List<Track> tracks;

  const _CollectionDetailScreen({
    required this.title,
    required this.subtitle,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Future<void> playAt(int index) async {
      try {
        await ref.read(playbackControllerProvider.notifier).setQueue(tracks, startIndex: index, autoplay: true);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
        }
        return;
      }
      if (!context.mounted) return;
      await NowPlayingRoute.open(context);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(

        slivers: [
          SliverAppBar.large(
            title: Text(title),
            expandedHeight: 170,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: ColoredBox(
                  color: Theme.of(context).appBarTheme.backgroundColor ??
                      Theme.of(context).colorScheme.surface,
                  child: FlexibleSpaceBar(
                    titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
                    background: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Text(
                          subtitle,
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: tracks.isEmpty ? null : () => playAt(0),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Воспроизвести'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: tracks.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            itemBuilder: (context, index) {
              final t = tracks[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: TrackArtwork(trackPath: t.filePath, size: 44, radius: 10),
                ),
                title: Text(t.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [t.artist, t.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                onTap: () => playAt(index),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class RecentCollection {
  final String title;
  final String subtitle;
  final String artworkTrackPath;
  final DateTime lastModified;
  final List<Track> tracks;

  const RecentCollection({
    required this.title,
    required this.subtitle,
    required this.artworkTrackPath,
    required this.lastModified,
    required this.tracks,
  });
}

final recentlyAddedCollectionsProvider = FutureProvider<List<RecentCollection>>((ref) async {
  final library = ref.watch(libraryControllerProvider);
  final tracks = library.tracks;

  if (tracks.isEmpty) return const <RecentCollection>[];

  final groups = <String, List<Track>>{};

  for (final t in tracks) {
    final artist = (t.artist ?? '').trim();
    final album = (t.album ?? '').trim();

    // Prefer album grouping; fall back to folder.
    final key = (album.isNotEmpty || artist.isNotEmpty)
        ? 'album|$artist|$album'
        : 'folder|${p.normalize(p.dirname(t.filePath))}';

    (groups[key] ??= <Track>[]).add(t);
  }

  // Limit background IO for huge libraries.
  final maxGroupsToConsider = groups.length > 1200 ? 1200 : groups.length;
  final entries = groups.entries.take(maxGroupsToConsider).toList(growable: false);

  final results = <RecentCollection>[];

  for (final entry in entries) {
    final list = entry.value;
    if (list.isEmpty) continue;

    final first = list.first;

    DateTime last;
    try {
      last = await File(first.filePath).lastModified();
    } catch (_) {
      last = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final artist = (first.artist ?? '').trim();
    final album = (first.album ?? '').trim();

    final isAlbum = entry.key.startsWith('album|');
    final title = isAlbum
        ? (album.isNotEmpty ? album : 'Unknown Album')
        : p.basename(p.dirname(first.filePath));

    final subtitle = isAlbum
        ? (artist.isNotEmpty ? artist : p.dirname(first.filePath))
        : p.dirname(first.filePath);

    results.add(
      RecentCollection(
        title: title,
        subtitle: subtitle,
        artworkTrackPath: first.filePath,
        lastModified: last,
        tracks: list,
      ),
    );
  }

  results.sort((a, b) => b.lastModified.compareTo(a.lastModified));
  return results.take(8).toList(growable: false);
});
