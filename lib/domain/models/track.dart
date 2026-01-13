import 'package:flutter/foundation.dart';

@immutable
class Track {
  final String filePath;

  final String? title;
  final String? artist;
  final String? album;

  final Duration? duration;

  final double? bpm;

  /// For CUE-split tracks: start & end offsets in the underlying file.
  final Duration? start;
  final Duration? end;

  const Track({
    required this.filePath,
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.bpm,
    this.start,
    this.end,
  });

  String get displayTitle {
    final t = title;
    if (t != null && t.trim().isNotEmpty) return t;

    final parts = filePath.split(RegExp(r'[/\\]'));
    final name = parts.isNotEmpty ? parts.last : filePath;

    // Trim common extensions for nicer display.
    return name.replaceFirst(RegExp(r'\.(mp3|m4a|aac|flac|wav|ogg|opus|ape|wv|wma|aif|aiff|caf|mka|mp4)$', caseSensitive: false), '');
  }

  /// Stable key for caching/overrides.
  ///
  /// Important for CUE-split tracks: multiple logical tracks can share one
  /// underlying audio file, so caching must include [start]/[end].
  String get uniqueKey {
    final s = start?.inMilliseconds ?? -1;
    final e = end?.inMilliseconds ?? -1;
    return '$filePath|$s|$e';
  }

  Track copyWith({
    String? filePath,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    double? bpm,
    Duration? start,
    Duration? end,
  }) {
    return Track(
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      bpm: bpm ?? this.bpm,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Track &&
            other.filePath == filePath &&
            other.title == title &&
            other.artist == artist &&
            other.album == album &&
            other.duration == duration &&
            other.bpm == bpm &&
            other.start == start &&
            other.end == end);
  }

  @override
  int get hashCode => Object.hash(filePath, title, artist, album, duration, bpm, start, end);
}
