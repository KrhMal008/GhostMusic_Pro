import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/models/track.dart';
import 'package:ghostmusic/domain/services/folder_art_service.dart';
import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/ui/artwork/artwork_view.dart';

final folderArtOverrideProvider = FutureProvider.autoDispose.family<FolderArtOverride?, String>((ref, folderPath) async {
  return FolderArtService.getForFolder(folderPath);
});

class FolderArtwork extends ConsumerWidget {
  final String folderPath;
  final List<Track> tracks;
  final double size;
  final double radius;

  const FolderArtwork({
    super.key,
    required this.folderPath,
    required this.tracks,
    this.size = 44,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final overrideAsync = ref.watch(folderArtOverrideProvider(folderPath));

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
        child: Icon(Icons.folder_rounded, color: cs.onSurface.withValues(alpha: 0.55)),
      );
    }

    Widget imageFile(String path) {
      final file = File(path);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    }

    Widget trackCover(String trackPath) {
      return SizedBox(
        width: size,
        height: size,
        child: TrackArtwork(
          trackPath: trackPath,
          size: size,
          radius: radius,
          fit: BoxFit.cover,
        ),
      );
    }

    Widget collage({required bool forceCollage}) {
      if (tracks.isEmpty) return fallback();

      // Pick up to 4 tracks as a preview.
      final preview = tracks.take(4).toList(growable: false);

      // Best-effort: if we can confirm all artwork paths are the same, show a single cover.
      if (!forceCollage && preview.isNotEmpty) {
        final paths = <String>{};
        for (final t in preview) {
          final art = ref.watch(trackArtworkPathProvider(t.filePath)).valueOrNull;
          if (art != null && art.trim().isNotEmpty) paths.add(art);
        }

        if (paths.length == 1) {
          return trackCover(preview.first.filePath);
        }
      }

      if (preview.length == 1) {
        return trackCover(preview.first.filePath);
      }

      Widget cell(Track t) {
        return TrackArtwork(
          trackPath: t.filePath,
          size: size,
          radius: 0,
          fit: BoxFit.cover,
        );
      }

      final pad = 1.0;

      final topLeft = preview.elementAt(0);
      final topRight = preview.length >= 2 ? preview.elementAt(1) : topLeft;
      final bottomLeft = preview.length >= 3 ? preview.elementAt(2) : topLeft;
      final bottomRight = preview.length >= 4 ? preview.elementAt(3) : topLeft;

      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.06)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: cell(topLeft)),
                      SizedBox(height: pad),
                      Expanded(child: cell(bottomLeft)),
                    ],
                  ),
                ),
                SizedBox(width: pad),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: cell(topRight)),
                      SizedBox(height: pad),
                      Expanded(child: cell(bottomRight)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return overrideAsync.when(
      data: (override) {
        final mode = override?.mode ?? FolderArtMode.auto;
        final value = override?.value;

        switch (mode) {
          case FolderArtMode.auto:
            return collage(forceCollage: false);
          case FolderArtMode.collage:
            return collage(forceCollage: true);
          case FolderArtMode.imageFile:
            if (value == null || value.trim().isEmpty) return fallback();
            return imageFile(value);
          case FolderArtMode.track:
            if (value == null || value.trim().isEmpty) return fallback();
            return trackCover(value);
        }
      },
      loading: () => collage(forceCollage: false),
      error: (_, __) => collage(forceCollage: false),
    );
  }
}
