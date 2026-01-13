import 'package:flutter/foundation.dart';

import '../models/track.dart';

@immutable
class LibraryState {
  final List<String> folders;
  final List<Track> tracks;

  final bool isScanning;
  final int scannedFiles;
  final String? lastError;

  const LibraryState({
    required this.folders,
    required this.tracks,
    required this.isScanning,
    required this.scannedFiles,
    required this.lastError,
  });

  const LibraryState.initial()
      : folders = const [],
        tracks = const [],
        isScanning = false,
        scannedFiles = 0,
        lastError = null;

  LibraryState copyWith({
    List<String>? folders,
    List<Track>? tracks,
    bool? isScanning,
    int? scannedFiles,
    String? lastError,
  }) {
    return LibraryState(
      folders: folders ?? this.folders,
      tracks: tracks ?? this.tracks,
      isScanning: isScanning ?? this.isScanning,
      scannedFiles: scannedFiles ?? this.scannedFiles,
      lastError: lastError,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is LibraryState &&
            listEquals(other.folders, folders) &&
            listEquals(other.tracks, tracks) &&
            other.isScanning == isScanning &&
            other.scannedFiles == scannedFiles &&
            other.lastError == lastError);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(folders),
        Object.hashAll(tracks),
        isScanning,
        scannedFiles,
        lastError,
      );
}
