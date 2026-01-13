import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/cue_parser.dart';
import '../services/metadata_service.dart';
import 'library_state.dart';

final libraryControllerProvider = StateNotifierProvider<LibraryController, LibraryState>((ref) {
  final controller = LibraryController();
  controller.load();
  return controller;
});

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController() : super(const LibraryState.initial());

  static const _prefsKeyFolders = 'library_folders';

  static const supportedExtensions = <String>{
    // Common
    '.mp3',
    '.m4a',
    '.aac',
    '.wav',
    '.aif',
    '.aiff',
    '.caf',

    // Lossless / extra codecs (may require MediaKit on some platforms)
    '.flac',
    '.ogg',
    '.opus',
    '.ape',
    '.wv',
    '.wma',

    // Containers sometimes used for audio-only
    '.mka',
    '.mp4',

    // Hi-res
    '.dsf',
    '.dff',

    // CUE sheets (will be expanded into tracks)
    '.cue',
  };

  int _scanToken = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_prefsKeyFolders) ?? const <String>[];

    state = state.copyWith(folders: folders);

    if (folders.isNotEmpty) {
      await rescan();
    }
  }

  Future<void> addFolder(String folderPath) async {
    if (folderPath.trim().isEmpty) return;

    final normalized = p.normalize(folderPath);

    final current = [...state.folders];
    if (current.contains(normalized)) return;

    current.add(normalized);

    state = state.copyWith(folders: current);
    await _persistFolders(current);
    await rescan();
  }

  Future<void> removeFolder(String folderPath) async {
    final normalized = p.normalize(folderPath);

    final next = state.folders.where((f) => p.normalize(f) != normalized).toList();

    state = state.copyWith(folders: next);
    await _persistFolders(next);
    await rescan();
  }

  Future<void> clearFolders() async {
    state = state.copyWith(folders: const [], tracks: const []);
    await _persistFolders(const []);
  }

  Future<void> rescan() async {
    final token = ++_scanToken;

    state = state.copyWith(
      isScanning: true,
      scannedFiles: 0,
      lastError: null,
    );

    try {
      final tracks = <Track>[];
      final cueTracks = <Track>[];
      final cueReferencedAudio = <String>{};
      var scanned = 0;

      for (final folder in state.folders) {
        if (token != _scanToken) return;

        final dir = Directory(folder);
        if (!await dir.exists()) {
          continue;
        }

        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (token != _scanToken) return;

          if (entity is! File) continue;

          final ext = p.extension(entity.path).toLowerCase();
          if (!supportedExtensions.contains(ext)) continue;

          scanned++;

          // CUE sheets: expand into per-track entries.
          if (ext == '.cue') {
            try {
              final parsed = await CueParser.parseFile(entity.path);
              cueTracks.addAll(parsed.tracks);
              cueReferencedAudio.addAll(parsed.referencedAudioPaths);
            } catch (_) {
              // Ignore parse errors; keep scanning.
            }

            if (scanned % 50 == 0) {
              state = state.copyWith(scannedFiles: scanned);
            }
            continue;
          }

          final relative = p.relative(entity.path, from: folder);
          final relParts = p.split(p.normalize(relative));

          String? guessArtist;
          String? guessAlbum;

          if (relParts.length >= 3) {
            guessAlbum = relParts[relParts.length - 2];
            guessArtist = relParts[relParts.length - 3];
          } else if (relParts.length == 2) {
            guessAlbum = relParts[0];
          }

          final base = Track(
            filePath: entity.path,
            title: p.basenameWithoutExtension(entity.path),
            artist: guessArtist,
            album: guessAlbum,
          );

          tracks.add(base);

          if (scanned % 50 == 0) {
            state = state.copyWith(scannedFiles: scanned);
          }
        }
      }

      final referenced = cueReferencedAudio.map(p.normalize).toSet();

      // If an audio file is referenced by a CUE sheet, prefer the split tracks.
      final baseTracks = tracks
          .where((t) => !referenced.contains(p.normalize(t.filePath)))
          .toList(growable: false);

      final allTracks = <Track>[...baseTracks, ...cueTracks];
      allTracks.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));

      state = state.copyWith(
        tracks: allTracks,
        isScanning: false,
        scannedFiles: scanned,
        lastError: null,
      );

      // Enrich metadata in the background to avoid UI jank.
      unawaited(_enrichMetadata(token, allTracks));
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        lastError: e.toString(),
      );
    }
  }

  Future<void> _enrichMetadata(int token, List<Track> baseTracks) async {
    // Work on a copy; update state periodically.
    final updated = [...baseTracks];

    for (var i = 0; i < updated.length; i++) {
      if (token != _scanToken) return;

      final enriched = await MetadataService.enrichTrack(updated[i]);
      updated[i] = enriched.track;

      if (i % 25 == 0) {
        // Yield back to UI.
        state = state.copyWith(tracks: [...updated]);
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    if (token != _scanToken) return;

    state = state.copyWith(tracks: updated);
  }

  Future<void> _persistFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKeyFolders, folders);
  }
}
