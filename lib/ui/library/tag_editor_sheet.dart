import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/models/track.dart';
import 'package:ghostmusic/domain/services/metadata_service.dart';
import 'package:ghostmusic/domain/services/tag_override_service.dart';
import 'package:ghostmusic/domain/state/library_controller.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';
import 'package:ghostmusic/ui/widgets/glass_surface.dart';

final tagEditorMetaProvider = FutureProvider.family<TrackMetadataResult, String>((ref, path) async {
  return MetadataService.enrichTrack(Track(filePath: path));
});

class TagEditorSheet {
  static Future<void> show(BuildContext context, String trackPath) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GlassSurface(
              variant: GlassVariant.solid,
              shape: GlassShape.roundedLarge,
              padding: EdgeInsets.zero,
              child: _TagEditorContent(trackPath: trackPath),
            ),
          ),
        );
      },
    );
  }
}

class _TagEditorContent extends ConsumerStatefulWidget {
  final String trackPath;

  const _TagEditorContent({required this.trackPath});

  @override
  ConsumerState<_TagEditorContent> createState() => _TagEditorContentState();
}

class _TagEditorContentState extends ConsumerState<_TagEditorContent> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _album;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _artist = TextEditingController();
    _album = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final metaAsync = ref.watch(tagEditorMetaProvider(widget.trackPath));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: metaAsync.when(
        data: (meta) {
          _title.text = _title.text.isEmpty ? (meta.track.title ?? '') : _title.text;
          _artist.text = _artist.text.isEmpty ? (meta.track.artist ?? '') : _artist.text;
          _album.text = _album.text.isEmpty ? (meta.track.album ?? '') : _album.text;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Редактировать теги', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                meta.track.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _artist,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Artist'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _album,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Album'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);

                        () async {
                          await TagOverrideService.clearForFile(widget.trackPath);
                          MetadataService.invalidate(widget.trackPath);
                          ref.invalidate(tagEditorMetaProvider(widget.trackPath));

                          // Update library UI quickly.
                          ref.read(libraryControllerProvider.notifier).rescan();

                          if (navigator.mounted) navigator.pop();
                        }();
                      },
                      child: const Text('Сбросить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final navigator = Navigator.of(context);

                        () async {
                          await TagOverrideService.setForFile(
                            widget.trackPath,
                            TrackTagOverride(
                              title: _title.text.trim(),
                              artist: _artist.text.trim(),
                              album: _album.text.trim(),
                            ),
                          );
                          MetadataService.invalidate(widget.trackPath);
                          ref.invalidate(tagEditorMetaProvider(widget.trackPath));

                          // Soft-refresh current list (avoid full scan later).
                          ref.read(libraryControllerProvider.notifier).rescan();

                          if (navigator.mounted) navigator.pop();
                        }();
                      },
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Это “виртуальные теги” внутри приложения — файл на диске не изменяется.',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 24),
          child: Row(
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Загрузка…'),
            ],
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Text('Ошибка: $e', style: TextStyle(color: cs.error)),
        ),
      ),
    );
  }
}
