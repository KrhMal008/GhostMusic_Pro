import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/track.dart';

class CueParseResult {
  final List<Track> tracks;
  final Set<String> referencedAudioPaths;

  const CueParseResult({required this.tracks, required this.referencedAudioPaths});
}

class CueParser {
  CueParser._();

  static Future<CueParseResult> parseFile(String cuePath) async {
    final file = File(cuePath);
    if (!await file.exists()) {
      return const CueParseResult(tracks: [], referencedAudioPaths: {});
    }

    final content = await file.readAsString();
    return parseString(content, cuePath: cuePath);
  }

  static CueParseResult parseString(String content, {required String cuePath}) {
    final cueDir = p.dirname(cuePath);

    String? sheetTitle;
    String? sheetPerformer;

    String? currentFileResolved;

    _WorkingTrack? working;
    final parsed = <_WorkingTrack>[];

    String? unquote(String raw) {
      var s = raw.trim();
      if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
        s = s.substring(1, s.length - 1);
      }
      s = s.trim();
      return s.isEmpty ? null : s;
    }

    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Common comment styles.
      if (line.startsWith(';')) continue;
      if (line.toUpperCase().startsWith('REM ')) continue;

      final fileMatch = RegExp(r'^FILE\s+(?:"([^"]+)"|(\S+))\s+.*$',
              caseSensitive: false)
          .firstMatch(line);
      if (fileMatch != null) {
        final fileName = unquote(fileMatch.group(1) ?? fileMatch.group(2) ?? '');
        if (fileName != null) {
          final resolved = p.isAbsolute(fileName)
              ? p.normalize(fileName)
              : p.normalize(p.join(cueDir, fileName));

          // Best-effort: if the resolved path doesn't exist, try a case-insensitive lookup
          // in the CUE directory (common when CUE was authored on another OS).
          String? fixed;
          try {
            if (!File(resolved).existsSync()) {
              final targetBase = p.basename(resolved).toLowerCase();
              for (final e in Directory(cueDir).listSync(followLinks: false)) {
                if (e is! File) continue;
                if (p.basename(e.path).toLowerCase() == targetBase) {
                  fixed = p.normalize(e.path);
                  break;
                }
              }
            }
          } catch (_) {}

          currentFileResolved = fixed ?? resolved;
        } else {
          currentFileResolved = null;
        }
        continue;
      }

      final trackMatch = RegExp(r'^TRACK\s+(\d{1,3})\s+\w+', caseSensitive: false)
          .firstMatch(line);
      if (trackMatch != null) {
        if (working != null) parsed.add(working);
        final n = int.tryParse(trackMatch.group(1) ?? '') ?? 0;
        working = _WorkingTrack(number: n, filePath: currentFileResolved);
        continue;
      }

      final titleMatch = RegExp(r'^TITLE\s+(.+)$', caseSensitive: false).firstMatch(line);
      if (titleMatch != null) {
        final v = unquote(titleMatch.group(1) ?? '');
        if (working != null) {
          working = working.copyWith(title: v);
        } else {
          sheetTitle = v ?? sheetTitle;
        }
        continue;
      }

      final perfMatch =
          RegExp(r'^PERFORMER\s+(.+)$', caseSensitive: false).firstMatch(line);
      if (perfMatch != null) {
        final v = unquote(perfMatch.group(1) ?? '');
        if (working != null) {
          working = working.copyWith(performer: v);
        } else {
          sheetPerformer = v ?? sheetPerformer;
        }
        continue;
      }

      final indexMatch = RegExp(r'^INDEX\s+01\s+(\d{1,3}):(\d{1,2}):(\d{1,2})$',
              caseSensitive: false)
          .firstMatch(line);
      if (indexMatch != null && working != null) {
        final mm = int.tryParse(indexMatch.group(1) ?? '') ?? 0;
        final ss = int.tryParse(indexMatch.group(2) ?? '') ?? 0;
        final ff = int.tryParse(indexMatch.group(3) ?? '') ?? 0;
        working = working.copyWith(start: _msfToDuration(mm, ss, ff));
        continue;
      }

      // Ignore unsupported directives (PREGAP, POSTGAP, INDEX 00, etc.) for now.
    }

    if (working != null) parsed.add(working);

    final out = <Track>[];
    for (var i = 0; i < parsed.length; i++) {
      final t = parsed[i];
      final next = i + 1 < parsed.length ? parsed[i + 1] : null;

      final filePath = t.filePath;
      final start = t.start;
      if (filePath == null || filePath.trim().isEmpty) continue;
      if (start == null) continue;

      Duration? end;
      if (next != null && next.filePath == t.filePath && next.start != null) {
        end = next.start;
        if (end != null && end <= start) end = null;
      }

      out.add(
        Track(
          filePath: filePath,
          title: t.title,
          artist: t.performer ?? sheetPerformer,
          album: sheetTitle,
          start: start,
          end: end,
        ),
      );
    }

    final referenced = out.map((t) => p.normalize(t.filePath)).toSet();
    return CueParseResult(tracks: out, referencedAudioPaths: referenced);
  }

  static Duration _msfToDuration(int mm, int ss, int ff) {
    // CUE frames are 75 per second.
    final totalMs = ((mm * 60 + ss) * 1000) + ((ff * 1000) / 75).round();
    return Duration(milliseconds: totalMs);
  }
}

class _WorkingTrack {
  final int number;
  final String? filePath;
  final String? title;
  final String? performer;
  final Duration? start;

  const _WorkingTrack({
    required this.number,
    required this.filePath,
    this.title,
    this.performer,
    this.start,
  });

  _WorkingTrack copyWith({
    int? number,
    String? filePath,
    String? title,
    String? performer,
    Duration? start,
  }) {
    return _WorkingTrack(
      number: number ?? this.number,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      performer: performer ?? this.performer,
      start: start ?? this.start,
    );
  }
}
