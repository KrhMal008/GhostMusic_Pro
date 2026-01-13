import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';
import 'tag_override_service.dart';

class TrackMetadataResult {
  final Track track;
  final String? artworkPath;

  const TrackMetadataResult({required this.track, required this.artworkPath});
}

class MetadataService {
  MetadataService._();

  static void invalidate(String filePath) {
    // We cache by Track.uniqueKey. Remove all cached entries for this file.
    _memo.removeWhere((k, _) => k.startsWith('$filePath|'));
  }

  static final Map<String, TrackMetadataResult> _memo = <String, TrackMetadataResult>{};

  static Future<TrackMetadataResult> enrichTrack(Track base) async {
    final key = base.uniqueKey;
    final cached = _memo[key];
    if (cached != null) return cached;

    final baseWithFallbacks = _applyPathFallbacks(base);

    TrackMetadataResult result;
    try {
      final ext = p.extension(baseWithFallbacks.filePath).toLowerCase();

      if (ext == '.mp3') {
        result = await _enrichMp3(baseWithFallbacks);
      } else {
        // For now: keep filename-based title, and let folder art / online search handle covers.
        result = TrackMetadataResult(track: baseWithFallbacks, artworkPath: null);
      }
    } catch (e) {
      debugPrint('MetadataService.enrichTrack failed: $e');
      result = TrackMetadataResult(track: baseWithFallbacks, artworkPath: null);
    }

    // Apply user overrides (virtual tags) last, so they win.
    final override = await TagOverrideService.getForFile(base.filePath);
    if (override != null) {
      result = TrackMetadataResult(
        track: result.track.copyWith(
          title: (override.title != null && override.title!.trim().isNotEmpty)
              ? override.title
              : result.track.title,
          artist: (override.artist != null && override.artist!.trim().isNotEmpty)
              ? override.artist
              : result.track.artist,
          album: (override.album != null && override.album!.trim().isNotEmpty)
              ? override.album
              : result.track.album,
        ),
        artworkPath: result.artworkPath,
      );
    }

    _memo[key] = result;
    return result;
  }

  static Track _applyPathFallbacks(Track base) {
    String? title = base.title;
    String? artist = base.artist;
    String? album = base.album;

    if (title == null || title.trim().isEmpty) {
      title = p.basenameWithoutExtension(base.filePath);
    }

    if ((artist == null || artist.trim().isEmpty) || (album == null || album.trim().isEmpty)) {
      try {
        final parts = p.split(p.normalize(base.filePath));
        if (parts.length >= 3) {
          final folderAlbum = parts[parts.length - 2].trim();
          final folderArtist = parts[parts.length - 3].trim();

          if ((album == null || album.trim().isEmpty) && folderAlbum.isNotEmpty) {
            album = folderAlbum;
          }
          if ((artist == null || artist.trim().isEmpty) && folderArtist.isNotEmpty) {
            artist = folderArtist;
          }
        }
      } catch (_) {
        // ignore
      }
    }

    return base.copyWith(title: title, artist: artist, album: album);
  }

  static Future<TrackMetadataResult> _enrichMp3(Track base) async {
    final id3 = await _readId3v2(base.filePath);

    // Fallback to ID3v1 if v2 had nothing.
    final id3v1 = (id3.title == null && id3.artist == null && id3.album == null)
        ? await _readId3v1(base.filePath)
        : const _Id3Result();

    final title = _pickString(id3.title) ?? _pickString(id3v1.title) ?? base.title;
    final artist = _pickString(id3.artist) ?? _pickString(id3v1.artist) ?? base.artist;
    final album = _pickString(id3.album) ?? _pickString(id3v1.album) ?? base.album;
    final bpm = id3.bpm;

    String? artworkPath;
    final pictureBytes = id3.pictureBytes;
    if (pictureBytes != null && pictureBytes.isNotEmpty) {
      artworkPath = await _writeArtworkToCache(
        base.filePath,
        pictureBytes,
        id3.pictureMime,
      );
    }

    return TrackMetadataResult(
      track: base.copyWith(
        title: title,
        artist: artist,
        album: album,
        bpm: bpm,
      ),
      artworkPath: artworkPath,
    );
  }

  static String? _pickString(String? s) {
    if (s == null) return null;
    final v = s.trim();
    if (v.isEmpty) return null;
    return v;
  }

  static double? _parseBpm(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;

    final normalized = s.replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite) return null;

    if (value <= 0 || value > 400) return null;
    return value;
  }

  static Future<String?> _writeArtworkToCache(
    String trackPath,
    Uint8List data,
    String? mimeType,
  ) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final cacheDir = Directory(p.join(dir.path, 'artwork_cache'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final ext = _extFromMimeOrMagic(mimeType, data) ?? '.jpg';
      final fileName = 'art_${trackPath.hashCode}$ext';
      final outFile = File(p.join(cacheDir.path, fileName));

      if (!await outFile.exists()) {
        await outFile.writeAsBytes(data, flush: true);
      }

      return outFile.path;
    } catch (e) {
      debugPrint('writeArtworkToCache failed: $e');
      return null;
    }
  }

  static String? _extFromMimeOrMagic(String? mimeType, Uint8List data) {
    final mt = mimeType?.toLowerCase();
    if (mt != null) {
      if (mt.contains('png')) return '.png';
      if (mt.contains('jpeg') || mt.contains('jpg')) return '.jpg';
    }

    // PNG signature
    if (data.length >= 8 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      return '.png';
    }

    // JPEG signature
    if (data.length >= 2 && data[0] == 0xFF && data[1] == 0xD8) {
      return '.jpg';
    }

    return null;
  }

  static Future<_Id3Result> _readId3v2(String path) async {
    final file = File(path);
    if (!await file.exists()) return const _Id3Result();

    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final header = await raf.read(10);
      if (header.length < 10) return const _Id3Result();

      if (header[0] != 0x49 || header[1] != 0x44 || header[2] != 0x33) {
        return const _Id3Result();
      }

      final major = header[3];
      // final revision = header[4];
      final flags = header[5];

      final tagSize = _decodeSynchsafeInt(header, 6);
      if (tagSize <= 0) return const _Id3Result();

      // Skip extended header if present (only in some versions).
      var tagBytes = await raf.read(tagSize);
      if (tagBytes.length < tagSize) {
        // best effort
      }

      // Handle unsynchronisation if global flag set (rare; we ignore for now).
      final hasUnsync = (flags & 0x80) != 0;
      if (hasUnsync) {
        tagBytes = _removeUnsynchronisation(tagBytes);
      }

      return _parseId3Frames(tagBytes, major: major);
    } catch (e) {
      debugPrint('readId3v2 failed: $e');
      return const _Id3Result();
    } finally {
      await raf?.close();
    }
  }

  static Uint8List _removeUnsynchronisation(Uint8List input) {
    // Replace 0xFF 0x00 -> 0xFF (best effort)
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < input.length; i++) {
      final b = input[i];
      if (b == 0xFF && i + 1 < input.length && input[i + 1] == 0x00) {
        out.addByte(0xFF);
        i++; // skip 0x00
      } else {
        out.addByte(b);
      }
    }
    return out.toBytes();
  }

  static _Id3Result _parseId3Frames(Uint8List bytes, {required int major}) {
    // Support ID3v2.3 and v2.4. v2.2 (3-char IDs) not supported.
    if (major < 3) return const _Id3Result();

    String? title;
    String? artist;
    String? album;
    double? bpm;
    Uint8List? pictureBytes;
    String? pictureMime;

    var offset = 0;

    while (offset + 10 <= bytes.length) {
      final id = ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true);
      if (id.trim().isEmpty || id.codeUnits.every((c) => c == 0)) break;

      final size = major == 4
          ? _decodeSynchsafeInt(bytes, offset + 4)
          : _decodeBigEndianInt(bytes, offset + 4);

      if (size <= 0) break;

      final frameStart = offset + 10;
      final frameEnd = frameStart + size;
      if (frameEnd > bytes.length) break;

      final content = Uint8List.sublistView(bytes, frameStart, frameEnd);

      if (id == 'TIT2') {
        title ??= _decodeTextFrame(content);
      } else if (id == 'TPE1') {
        artist ??= _decodeTextFrame(content);
      } else if (id == 'TALB') {
        album ??= _decodeTextFrame(content);
      } else if (id == 'TBPM') {
        bpm ??= _parseBpm(_decodeTextFrame(content));
      } else if (id == 'APIC' && (pictureBytes == null || pictureBytes.isEmpty)) {
        final pic = _decodeApic(content);
        if (pic != null) {
          pictureBytes = pic.$1;
          pictureMime = pic.$2;
        }
      }

      offset = frameEnd;
    }

    return _Id3Result(
      title: title,
      artist: artist,
      album: album,
      bpm: bpm,
      pictureBytes: pictureBytes,
      pictureMime: pictureMime,
    );
  }

  static String? _decodeTextFrame(Uint8List content) {
    if (content.isEmpty) return null;

    final encoding = content[0];
    final textBytes = Uint8List.sublistView(content, 1);

    return _decodeText(encoding, textBytes);
  }

  static (Uint8List, String?)? _decodeApic(Uint8List content) {
    if (content.length < 4) return null;

    var offset = 0;
    final encoding = content[offset++];

    // MIME is always ISO-8859-1 null-terminated.
    final mimeEnd = _indexOfZero(content, offset);
    if (mimeEnd == -1) return null;
    final mime = latin1.decode(content.sublist(offset, mimeEnd), allowInvalid: true);
    offset = mimeEnd + 1;

    if (offset >= content.length) return null;
    // picture type
    offset++;

    // description is null-terminated string in given encoding.
    final descTerminator = _findStringTerminator(content, offset, encoding);
    if (descTerminator == -1) return null;
    offset = descTerminator;

    // Skip terminator (1 byte for ISO/UTF-8, 2 bytes for UTF-16 variants)
    offset += (encoding == 1 || encoding == 2) ? 2 : 1;

    if (offset >= content.length) return null;

    final data = content.sublist(offset);
    return (Uint8List.fromList(data), mime);
  }

  static int _indexOfZero(Uint8List bytes, int start) {
    for (var i = start; i < bytes.length; i++) {
      if (bytes[i] == 0) return i;
    }
    return -1;
  }

  static int _findStringTerminator(Uint8List bytes, int start, int encoding) {
    if (encoding == 1 || encoding == 2) {
      // UTF-16/UTF-16BE: terminator is 0x00 0x00
      for (var i = start; i + 1 < bytes.length; i += 2) {
        if (bytes[i] == 0 && bytes[i + 1] == 0) return i;
      }
      return -1;
    }

    // ISO-8859-1 or UTF-8: single 0x00
    return _indexOfZero(bytes, start);
  }

  static String? _decodeText(int encoding, Uint8List bytes) {
    if (bytes.isEmpty) return null;

    switch (encoding) {
      case 0:
        return _trimNulls(latin1.decode(bytes, allowInvalid: true));
      case 3:
        return _trimNulls(utf8.decode(bytes, allowMalformed: true));
      case 1:
        return _trimNulls(_decodeUtf16(bytes));
      case 2:
        return _trimNulls(_decodeUtf16(bytes, forceBigEndian: true));
      default:
        return _trimNulls(utf8.decode(bytes, allowMalformed: true));
    }
  }

  static String _trimNulls(String s) {
    return s.replaceAll('\u0000', '').trim();
  }

  static String _decodeUtf16(Uint8List bytes, {bool forceBigEndian = false}) {
    if (bytes.length < 2) return '';

    var offset = 0;
    var bigEndian = forceBigEndian;

    if (!forceBigEndian) {
      // BOM
      final b0 = bytes[0];
      final b1 = bytes[1];
      if (b0 == 0xFF && b1 == 0xFE) {
        bigEndian = false;
        offset = 2;
      } else if (b0 == 0xFE && b1 == 0xFF) {
        bigEndian = true;
        offset = 2;
      }
    }

    final len = (bytes.length - offset) ~/ 2;
    final codeUnits = Uint16List(len);

    for (var i = 0; i < len; i++) {
      final bIndex = offset + i * 2;
      final bA = bytes[bIndex];
      final bB = bytes[bIndex + 1];
      codeUnits[i] = bigEndian ? ((bA << 8) | bB) : ((bB << 8) | bA);
    }

    return String.fromCharCodes(codeUnits);
  }

  static int _decodeSynchsafeInt(Uint8List bytes, int offset) {
    // 4 bytes, 7 bits each
    if (offset + 3 >= bytes.length) return 0;
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  static int _decodeBigEndianInt(Uint8List bytes, int offset) {
    if (offset + 3 >= bytes.length) return 0;
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        (bytes[offset + 3]);
  }

  static Future<_Id3Result> _readId3v1(String path) async {
    final file = File(path);
    if (!await file.exists()) return const _Id3Result();

    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final len = await raf.length();
      if (len < 128) return const _Id3Result();

      await raf.setPosition(len - 128);
      final buf = await raf.read(128);
      if (buf.length < 128) return const _Id3Result();

      if (buf[0] != 0x54 || buf[1] != 0x41 || buf[2] != 0x47) {
        return const _Id3Result();
      }

      final title = _trimNulls(latin1.decode(buf.sublist(3, 33), allowInvalid: true));
      final artist = _trimNulls(latin1.decode(buf.sublist(33, 63), allowInvalid: true));
      final album = _trimNulls(latin1.decode(buf.sublist(63, 93), allowInvalid: true));

      return _Id3Result(title: title, artist: artist, album: album);
    } catch (_) {
      return const _Id3Result();
    } finally {
      await raf?.close();
    }
  }
}

@immutable
class _Id3Result {
  final String? title;
  final String? artist;
  final String? album;
  final double? bpm;
  final Uint8List? pictureBytes;
  final String? pictureMime;

  const _Id3Result({
    this.title,
    this.artist,
    this.album,
    this.bpm,
    this.pictureBytes,
    this.pictureMime,
  });
}
