import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/state/playback_controller.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

class TrackArtwork extends ConsumerWidget {
  final String trackPath;
  final double size;
  final double radius;
  final BoxFit fit;

  const TrackArtwork({
    super.key,
    required this.trackPath,
    required this.size,
    required this.radius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artworkAsync = ref.watch(trackArtworkPathProvider(trackPath));

    Widget content = artworkAsync.when(
      data: (path) {
        if (path == null) return _Placeholder(trackPath: trackPath);
        return Image.file(
          File(path),
          fit: fit,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _Placeholder(trackPath: trackPath),
        );
      },
      loading: () => _Placeholder(trackPath: trackPath),
      error: (_, __) => _Placeholder(trackPath: trackPath),
    );

    // Avoid forcing infinite sizing when used inside Positioned.fill/AspectRatio.
    if (size.isFinite) {
      content = SizedBox(width: size, height: size, child: content);
    } else {
      content = SizedBox.expand(child: content);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String trackPath;

  const _Placeholder({required this.trackPath});

  @override
  Widget build(BuildContext context) {
    final seed = trackPath.hashCode;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.artworkPlaceholder(seed),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }
}
