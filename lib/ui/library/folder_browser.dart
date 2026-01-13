import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:ghostmusic/domain/models/track.dart';
import 'package:ghostmusic/domain/services/folder_art_service.dart';
import 'package:ghostmusic/domain/state/library_controller.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/ui/artwork/artwork_view.dart';
import 'package:ghostmusic/ui/artwork/folder_artwork.dart';
import 'package:ghostmusic/ui/player/mini_player.dart';
import 'package:ghostmusic/ui/player/now_playing_route.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_app_bar.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';


final folderSubfoldersProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, folderPath) async {
  final dir = Directory(folderPath);
  if (!await dir.exists()) return const <String>[];

  final subs = <String>[];

  await for (final entity in dir.list(followLinks: false)) {
    if (entity is Directory) {
      subs.add(p.normalize(entity.path));
    }
  }

  subs.sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));

  return subs;
});

class FolderBrowserScreen extends ConsumerWidget {
  final String rootFolder;
  final String folder;

  const FolderBrowserScreen({
    super.key,
    required this.rootFolder,
    required this.folder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final playback = ref.watch(playbackControllerProvider);

    final derivedSubFolders = _collectSubfolders(library.tracks, rootFolder, folder);
    final fsSubFolders = ref.watch(folderSubfoldersProvider(folder)).valueOrNull ?? const <String>[];

    final subFolders = {...fsSubFolders, ...derivedSubFolders}.toList()
      ..sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));

    final files = _tracksInFolder(library.tracks, folder);

    final controller = ref.read(playbackControllerProvider.notifier);

    Future<void> openNowPlaying() async {
      HapticFeedback.selectionClick();
      await NowPlayingRoute.open(context);
    }

    Future<void> createFolder() async {
      HapticFeedback.selectionClick();

      final textController = TextEditingController();
      final result = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Создать папку',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Новая папка',
                    ),
                    onSubmitted: (_) => Navigator.of(ctx).pop(textController.text),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(textController.text),
                          child: const Text('Создать'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
      textController.dispose();

      final rawName = (result ?? '').trim();
      final safeName = _sanitizeFolderName(rawName);
      if (safeName.isEmpty) return;

      try {
        await Directory(p.join(folder, safeName)).create(recursive: true);
        ref.invalidate(folderSubfoldersProvider(folder));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Папка создана: $safeName')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось создать папку: $e')),
          );
        }
      }
    }

    Future<void> openFolderCoverMenu(String folderPath, List<Track> coverTracks) async {
      HapticFeedback.selectionClick();

      Future<void> setOverride(FolderArtOverride override) async {
        await FolderArtService.setForFolder(folderPath, override);
        ref.invalidate(folderArtOverrideProvider(folderPath));
      }

      Future<void> clearOverride() async {
        await FolderArtService.clearForFolder(folderPath);
        ref.invalidate(folderArtOverrideProvider(folderPath));
      }

      Future<String?> pickTrackCover() {
        final items = coverTracks.take(120).toList(growable: false);

        return showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withValues(alpha: 0.60),
          isScrollControlled: true,
          builder: (ctx) {
            final height = MediaQuery.sizeOf(ctx).height * 0.75;
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
                            [t.artist, t.album].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(ctx).pop(t.filePath),
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

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.60),
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
                      leading: const Icon(Icons.auto_awesome_rounded),
                      title: const Text('Авто'),
                      subtitle: const Text('Одна обложка если одинаковая, иначе коллаж'),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await clearOverride();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.grid_view_rounded),
                      title: const Text('Коллаж'),
                      subtitle: const Text('Всегда показывать коллаж'),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await setOverride(const FolderArtOverride(mode: FolderArtMode.collage));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.image_rounded),
                      title: const Text('Выбрать картинку…'),
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
                      title: const Text('Выбрать обложку трека…'),
                      subtitle: const Text('Из треков этой папки'),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final selected = await pickTrackCover();
                        if (selected == null || selected.trim().isEmpty) return;
                        await setOverride(FolderArtOverride(mode: FolderArtMode.track, value: selected));
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

    final bottomOverlay = MediaQuery.paddingOf(context).bottom + AppHitTarget.miniPlayerHeight + 24;

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: MiniPlayer(
          onTap: openNowPlaying,
          onNext: controller.next,
          onPrevious: controller.previous,
          onPlayPause: controller.togglePlayPause,
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            GlassSliverAppBar.large(
              title: Text(p.basename(folder).isEmpty ? 'Папки' : p.basename(folder)),
              actions: [
                IconButton(
                  tooltip: 'Создать папку',
                  icon: const Icon(Icons.create_new_folder_rounded),
                  onPressed: createFolder,
                ),
                const SizedBox(width: 12),
              ],
            ),
          ];
        },
        body: Center(

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: EdgeInsets.only(bottom: bottomOverlay),
            children: [

              if (subFolders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'Папки',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...subFolders.map((f) {
              final coverTracks = _tracksUnderFolder(library.tracks, rootFolder, f);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: FolderArtwork(
                  folderPath: f,
                  tracks: coverTracks,
                  size: 44,
                  radius: 12,
                ),
                title: Text(
                  p.basename(f),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  f,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: GlassSurface.chip(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    coverTracks.isEmpty ? '—' : '${coverTracks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                onLongPress: coverTracks.isEmpty
                    ? null
                    : () => openFolderCoverMenu(f, coverTracks),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FolderBrowserScreen(rootFolder: rootFolder, folder: f),
                    ),
                  );
                },
              );
            }),

            const Divider(height: 24),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Треки',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                GlassSurface.bar(
                  variant: GlassVariant.ultraThin,
                  radius: 999,
                  shadowEnabled: false,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Перемешать',
                        onPressed: files.isEmpty
                            ? null
                            : () {
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);

                                () async {
                                  final shuffled = files.toList()..shuffle();
                                  await ref
                                      .read(playbackControllerProvider.notifier)
                                      .setQueue(shuffled, startIndex: 0, autoplay: true);
                                  HapticFeedback.selectionClick();
                                  if (!navigator.mounted) return;
                                  await NowPlayingRoute.open(navigator.context);
                                }().catchError((e) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Play failed: $e')),
                                  );
                                });
                              },
                        icon: const Icon(Icons.shuffle_rounded),
                      ),
                      IconButton(
                        tooltip: 'Воспроизвести',
                        onPressed: files.isEmpty
                            ? null
                            : () {
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);

                                () async {
                                  const start = 0;
                                  await ref
                                      .read(playbackControllerProvider.notifier)
                                      .setQueue(files, startIndex: start, autoplay: true);
                                  HapticFeedback.selectionClick();
                                  if (!navigator.mounted) return;
                                  await NowPlayingRoute.open(navigator.context);
                                }().catchError((e) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Play failed: $e')),
                                  );
                                });
                              },
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'В этой папке нет треков',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            ...List.generate(files.length, (index) {
              final track = files[index];
              final isCurrent = playback.currentTrack?.filePath == track.filePath;

              return ListTile(
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TrackArtwork(
                        trackPath: track.filePath,
                        size: 44,
                        radius: 10,
                      ),
                      if (isCurrent)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      if (isCurrent)
                        Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                    ],
                  ),
                ),

                title: Text(track.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [track.artist, track.album].whereType<String>().join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  () async {
                    await ref
                        .read(playbackControllerProvider.notifier)
                        .setQueue(files, startIndex: index, autoplay: true);
                    HapticFeedback.selectionClick();
                    if (!navigator.mounted) return;
                    await NowPlayingRoute.open(navigator.context);
                  }().catchError((e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Play failed: $e')),
                    );
                  });
                },
              );
            }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      ),
    );

  }

  static List<Track> _tracksInFolder(List<Track> all, String folder) {
    final normalizedFolder = p.normalize(folder);

    final result = all
        .where((t) => p.normalize(p.dirname(t.filePath)) == normalizedFolder)
        .toList();

    result.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));

    return result;
  }

  static List<Track> _tracksUnderFolder(List<Track> all, String rootFolder, String folder) {
    final normalizedFolder = p.normalize(folder);
    final root = p.normalize(rootFolder);

    final result = <Track>[];

    for (final t in all) {
      final dir = p.normalize(p.dirname(t.filePath));
      if (!p.isWithin(root, dir) && dir != root) continue;

      if (dir == normalizedFolder || p.isWithin(normalizedFolder, dir)) {
        result.add(t);
      }
    }

    result.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
    return result;
  }

  static List<String> _collectSubfolders(

    List<Track> all,
    String rootFolder,
    String folder,
  ) {
    final normalizedFolder = p.normalize(folder);
    final root = p.normalize(rootFolder);

    final subs = <String>{};

    for (final t in all) {
      final dir = p.normalize(p.dirname(t.filePath));
      if (!p.isWithin(root, dir) && dir != root) continue;

      if (dir == normalizedFolder) continue;

      final parent = p.normalize(p.dirname(dir));
      if (parent == normalizedFolder) {
        subs.add(dir);
      }
    }

    final list = subs.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

String _sanitizeFolderName(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';

  // Windows reserved characters: <>:"/\\|?*
  var name = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

  // Avoid trailing dots/spaces (Windows) and reserved names.
  name = name.replaceAll(RegExp(r'[\\. ]+$'), '').trim();

  if (name.isEmpty) return '';
  if (name == '.' || name == '..') return '';

  // Keep names reasonable for UI.
  if (name.length > 80) {
    name = name.substring(0, 80).trim();
  }

  return name;
}
