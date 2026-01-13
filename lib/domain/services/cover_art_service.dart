import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import 'metadata_service.dart';

@immutable
class CoverCandidate {
  final String provider;
  final String title;
  final String subtitle;
  final Uri imageUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  const CoverCandidate({
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
  });
  
  /// Returns the best URL for preview (thumbnail if available, otherwise main image)
  String get previewUrl => thumbnailUrl ?? imageUrl.toString();
}

class CoverArtService {
  CoverArtService._();

  static final Map<String, Future<String?>> _inflight = <String, Future<String?>>{};
  static final Set<String> _loggedOnce = <String>{};

  static void _logOnce(String message, Object error) {
    if (!_loggedOnce.add(message)) return;

    if (error is TimeoutException) {
      debugPrint('$message: $error (проверь интернет/прокси)');
      return;
    }

    if (error is SocketException || error is HandshakeException) {
      debugPrint('$message: $error (проверь интернет/прокси/сертификаты)');
      return;
    }

    debugPrint('$message: $error');
  }

  static Future<String?> getOrFetchForFile(String trackPath) async {
    final meta = await MetadataService.enrichTrack(Track(filePath: trackPath));

    String? artist = meta.track.artist;
    String? album = meta.track.album;

    // If tags are missing, try to infer from folder structure.
    if ((artist == null || artist.trim().isEmpty) || (album == null || album.trim().isEmpty)) {
      final guess = _guessArtistAlbum(trackPath);
      artist = artist?.trim().isNotEmpty == true ? artist : guess.$1;
      album = album?.trim().isNotEmpty == true ? album : guess.$2;
    }

    // We need at least artist+album for reliable results.
    if (artist == null || artist.trim().isEmpty) return null;
    if (album == null || album.trim().isEmpty) return null;

    return getOrFetchByArtistAlbum(artist: artist, album: album);
  }

  static Future<String?> getOrFetchByArtistAlbum({
    required String artist,
    required String album,
  }) {
    final key = _cacheKey(artist: artist, album: album);

    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = () async {
      // 0) User override
      final override = await getOverrideByArtistAlbum(artist: artist, album: album);
      if (override != null) return override;

      // 1) Cache
      final cached = await _readCached(key);
      if (cached != null) return cached;

      // 2) MusicBrainz + Cover Art Archive (trusted, open)
      try {
        final caa = await _fetchViaCoverArtArchive(artist: artist, album: album);
        if (caa != null) return caa;
      } catch (e) {
        _logOnce('CAA fetch error', e);
      }

      // 3) Deezer (no key, fast)
      try {
        final deezer = await _fetchViaDeezer(artist: artist, album: album);
        if (deezer != null) return deezer;
      } catch (e) {
        _logOnce('Deezer fetch error', e);
      }

      // 4) iTunes Search (fallback, often good quality)
      try {
        final itunes = await _fetchViaITunes(artist: artist, album: album);
        if (itunes != null) return itunes;
      } catch (e) {
        _logOnce('iTunes fetch error', e);
      }

      // 5) Wikimedia Commons (public, best-effort)
      try {
        final wiki = await _fetchViaWikimedia(artist: artist, album: album);
        if (wiki != null) return wiki;
      } catch (e) {
        _logOnce('Wikimedia fetch error', e);
      }

      // 6) Discogs (trusted, but requires a user-provided token)
      final token = await _getDiscogsToken();
      if (token != null) {
        try {
          final discogs = await _fetchViaDiscogs(artist: artist, album: album, token: token);
          if (discogs != null) return discogs;
        } catch (e) {
            _logOnce('Discogs fetch error', e);
        }
      }

      // 6) Last.fm (web scraping fallback)
      try {
        final lastfm = await _fetchViaLastFm(artist: artist, album: album);
        if (lastfm != null) return lastfm;
      } catch (e) {
        _logOnce('Last.fm fetch error', e);
      }

      return null;
    }();

    _inflight[key] = future;

    return future.whenComplete(() {
      _inflight.remove(key);
    });
  }

  static String _cacheKey({required String artist, required String album}) {
    final a = artist.trim().toLowerCase();
    final b = album.trim().toLowerCase();
    return _safeFileKey('$a|$b');
  }

  static (String?, String?) _guessArtistAlbum(String trackPath) {
    try {
      final parts = p.split(p.normalize(trackPath));
      if (parts.length < 3) return (null, null);

      // .../Artist/Album/Track.ext
      final album = parts[parts.length - 2];
      final artist = parts[parts.length - 3];

      final a = artist.trim();
      final b = album.trim();

      if (a.isEmpty || b.isEmpty) return (null, null);
      return (a, b);
    } catch (_) {
      return (null, null);
    }
  }

  static String _safeFileKey(String raw) {
    // Keep it filesystem-safe and deterministic.
    final cleaned = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9._\-\| ]'), '')
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('|', '__');

    if (cleaned.length <= 80) return cleaned;
    return '${cleaned.substring(0, 80)}_${raw.hashCode}';
  }

  static Future<Directory> _cacheDir() async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(p.join(dir.path, 'artwork_net_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  static Future<Directory> _overridesDir() async {
    final dir = await getApplicationSupportDirectory();
    final overrides = Directory(p.join(dir.path, 'artwork_overrides'));
    if (!await overrides.exists()) {
      await overrides.create(recursive: true);
    }
    return overrides;
  }

  static String _trackOverrideKey(String trackPath) {
    final normalized = p.normalize(trackPath).toLowerCase();
    return _safeFileKey(normalized);
  }

  static Future<String?> getOverrideByTrackPath(String trackPath) async {
    try {
      final key = _trackOverrideKey(trackPath);
      final dir = await _overridesDir();

      final jpg = File(p.join(dir.path, 'trk_$key.jpg'));
      if (await jpg.exists()) return jpg.path;

      final png = File(p.join(dir.path, 'trk_$key.png'));
      if (await png.exists()) return png.path;

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearOverrideByTrackPath(String trackPath) async {
    try {
      final key = _trackOverrideKey(trackPath);
      final dir = await _overridesDir();

      final jpg = File(p.join(dir.path, 'trk_$key.jpg'));
      final png = File(p.join(dir.path, 'trk_$key.png'));
      if (await jpg.exists()) await jpg.delete();
      if (await png.exists()) await png.delete();
    } catch (_) {}
  }

  static Future<String?> saveOverrideForTrackFromUrl({
    required String trackPath,
    required Uri imageUrl,
  }) async {
    try {
      final resp = await http
          .get(imageUrl, headers: {'User-Agent': 'GhostMusic/1.0', 'Accept': 'image/*'})
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

      final dir = await _overridesDir();
      final key = _trackOverrideKey(trackPath);
      final ext = _extFromContentTypeOrMagic(resp.headers['content-type'], resp.bodyBytes) ?? '.jpg';

      // Clear old files (jpg/png)
      final oldJpg = File(p.join(dir.path, 'trk_$key.jpg'));
      final oldPng = File(p.join(dir.path, 'trk_$key.png'));
      if (await oldJpg.exists()) await oldJpg.delete();
      if (await oldPng.exists()) await oldPng.delete();

      final out = File(p.join(dir.path, 'trk_$key$ext'));
      await out.writeAsBytes(resp.bodyBytes, flush: true);
      return out.path;
    } catch (e) {
      _logOnce('saveOverrideForTrackFromUrl failed', e);
      return null;
    }
  }

  static Future<String?> getOverrideByArtistAlbum({
    required String artist,
    required String album,
  }) async {
    try {
      final key = _cacheKey(artist: artist, album: album);
      final dir = await _overridesDir();

      final jpg = File(p.join(dir.path, 'ov_$key.jpg'));
      if (await jpg.exists()) return jpg.path;

      final png = File(p.join(dir.path, 'ov_$key.png'));
      if (await png.exists()) return png.path;

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearOverrideByArtistAlbum({
    required String artist,
    required String album,
  }) async {
    try {
      final key = _cacheKey(artist: artist, album: album);
      final dir = await _overridesDir();
      final jpg = File(p.join(dir.path, 'ov_$key.jpg'));
      final png = File(p.join(dir.path, 'ov_$key.png'));
      if (await jpg.exists()) await jpg.delete();
      if (await png.exists()) await png.delete();
    } catch (_) {}
  }

  static Future<String?> saveOverrideFromUrl({
    required String artist,
    required String album,
    required Uri imageUrl,
  }) async {
    try {
      final resp = await http
          .get(imageUrl, headers: {'User-Agent': 'GhostMusic/1.0', 'Accept': 'image/*'})
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

      final dir = await _overridesDir();
      final key = _cacheKey(artist: artist, album: album);
      final ext = _extFromContentTypeOrMagic(resp.headers['content-type'], resp.bodyBytes) ?? '.jpg';

      // Clear old files (jpg/png)
      final oldJpg = File(p.join(dir.path, 'ov_$key.jpg'));
      final oldPng = File(p.join(dir.path, 'ov_$key.png'));
      if (await oldJpg.exists()) await oldJpg.delete();
      if (await oldPng.exists()) await oldPng.delete();

      final out = File(p.join(dir.path, 'ov_$key$ext'));
      await out.writeAsBytes(resp.bodyBytes, flush: true);
      return out.path;
    } catch (e) {
      _logOnce('saveOverrideFromUrl failed', e);
      return null;
    }
  }

  static Future<String?> getOverrideForFile(String trackPath) async {
    final trackOverride = await getOverrideByTrackPath(trackPath);
    if (trackOverride != null) return trackOverride;

    final meta = await MetadataService.enrichTrack(Track(filePath: trackPath));

    String? artist = meta.track.artist;
    String? album = meta.track.album;

    if ((artist == null || artist.trim().isEmpty) || (album == null || album.trim().isEmpty)) {
      final guess = _guessArtistAlbum(trackPath);
      artist = artist?.trim().isNotEmpty == true ? artist : guess.$1;
      album = album?.trim().isNotEmpty == true ? album : guess.$2;
    }

    if (artist == null || artist.trim().isEmpty) return null;
    if (album == null || album.trim().isEmpty) return null;

    return getOverrideByArtistAlbum(artist: artist, album: album);
  }

  static Future<String?> _readCached(String key) async {
    try {
      final dir = await _cacheDir();
      final jpg = File(p.join(dir.path, 'net_$key.jpg'));
      if (await jpg.exists()) return jpg.path;
      final png = File(p.join(dir.path, 'net_$key.png'));
      if (await png.exists()) return png.path;
    } catch (_) {}

    return null;
  }

  static Future<void> clearNetCacheForArtistAlbum({
    required String artist,
    required String album,
  }) async {
    try {
      final key = _cacheKey(artist: artist, album: album);
      final dir = await _cacheDir();

      final jpg = File(p.join(dir.path, 'net_$key.jpg'));
      final png = File(p.join(dir.path, 'net_$key.png'));
      if (await jpg.exists()) await jpg.delete();
      if (await png.exists()) await png.delete();
    } catch (_) {
      // ignore
    }
  }

  static Future<void> clearNetCacheForFile(String trackPath) async {
    try {
      final meta = await MetadataService.enrichTrack(Track(filePath: trackPath));

      String? artist = meta.track.artist;
      String? album = meta.track.album;

      if ((artist == null || artist.trim().isEmpty) || (album == null || album.trim().isEmpty)) {
        final guess = _guessArtistAlbum(trackPath);
        artist = artist?.trim().isNotEmpty == true ? artist : guess.$1;
        album = album?.trim().isNotEmpty == true ? album : guess.$2;
      }

      if (artist == null || artist.trim().isEmpty) return;
      if (album == null || album.trim().isEmpty) return;

      await clearNetCacheForArtistAlbum(artist: artist, album: album);
    } catch (_) {
      // ignore
    }
  }

  static Future<String?> _writeCached(String key, Uint8List bytes, {String? contentType}) async {
    try {
      final dir = await _cacheDir();
      final ext = _extFromContentTypeOrMagic(contentType, bytes) ?? '.jpg';

      // Clear old cache variants (jpg/png) to avoid stale hits.
      final oldJpg = File(p.join(dir.path, 'net_$key.jpg'));
      final oldPng = File(p.join(dir.path, 'net_$key.png'));
      if (await oldJpg.exists()) await oldJpg.delete();
      if (await oldPng.exists()) await oldPng.delete();

      final out = File(p.join(dir.path, 'net_$key$ext'));
      await out.writeAsBytes(bytes, flush: true);
      return out.path;
    } catch (e) {
      debugPrint('CoverArtService cache write failed: $e');
      return null;
    }
  }

  static String? _extFromContentTypeOrMagic(String? contentType, Uint8List data) {
    final ct = contentType?.toLowerCase();
    if (ct != null) {
      if (ct.contains('png')) return '.png';
      if (ct.contains('jpeg') || ct.contains('jpg')) return '.jpg';
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

  static Future<List<CoverCandidate>> searchCandidates({
    required String artist,
    required String album,
  }) async {
    final candidates = <CoverCandidate>[];

    // Run searches in parallel for better performance
    final futures = <Future<List<CoverCandidate>>>[];

    // Primary sources (music databases)
    futures.add(_searchMusicBrainzCandidates(artist: artist, album: album));
    futures.add(_searchDeezerCandidates(artist: artist, album: album));
    futures.add(_searchITunesCandidates(artist: artist, album: album));

    // Discogs (requires token)
    final token = await _getDiscogsToken();
    if (token != null) {
      futures.add(_searchDiscogsCandidates(artist: artist, album: album, token: token));
    }

    // Secondary sources (web search for more options)
    futures.add(_searchLastFmCandidates(artist: artist, album: album));
    futures.add(_searchSpotifyCandidates(artist: artist, album: album));
    futures.add(_searchSoundCloudCandidates(query: '$artist $album', subtitle: artist));
    futures.add(_searchDuckDuckGoCandidates(query: '$artist $album album cover', subtitle: artist));
    futures.add(_searchBingImagesCandidates(query: '$artist $album', subtitle: artist));
    futures.add(_searchWikimediaCandidates(query: '$artist $album album cover', subtitle: artist, title: album));

    // Wait for all searches
    final results = await Future.wait(futures);
    for (final list in results) {
      candidates.addAll(list);
    }

    // De-dup by url
    final seen = <String>{};
    final out = <CoverCandidate>[];
    for (final c in candidates) {
      final k = c.imageUrl.toString();
      if (seen.add(k)) out.add(c);
    }

    return out;
  }

  static Future<List<CoverCandidate>> _searchMusicBrainzCandidates({
    required String artist,
    required String album,
  }) async {
    try {
      final query = 'release:"$album" AND artist:"$artist"';
      final uri = Uri.https('musicbrainz.org', '/ws/2/release/', {
        'query': query,
        'fmt': 'json',
        'limit': '5',
      });

      final resp = await http.get(
        uri,
        headers: {
          'User-Agent': 'GhostMusic/1.0 (contact: dev@local)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final releases = (decoded['releases'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (releases.isEmpty) return const [];

      return releases
          .map((r) {
            final id = r['id'] as String?;
            final title = r['title'] as String?;
            if (id == null || id.isEmpty) return null;

            final url = Uri.https('coverartarchive.org', '/release/$id/front-250');
            return CoverCandidate(
              provider: 'MusicBrainz/CAA',
              title: title ?? album,
              subtitle: artist,
              imageUrl: url,
            );
          })
          .whereType<CoverCandidate>()
          .toList(growable: false);
    } catch (e) {
      _logOnce('MusicBrainz candidate search failed', e);
      return const [];
    }
  }

  static Future<List<CoverCandidate>> _searchDiscogsCandidates({
    required String artist,
    required String album,
    required String token,
  }) async {
    try {
      final uri = Uri.https('api.discogs.com', '/database/search', {
        'type': 'release',
        'per_page': '10',
        'artist': artist,
        'release_title': album,
      });

      final resp = await http.get(
        uri,
        headers: {
          'User-Agent': 'GhostMusic/1.0 (contact: dev@local)',
          'Accept': 'application/json',
          'Authorization': 'Discogs token=$token',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (results.isEmpty) return const [];

      final out = <CoverCandidate>[];
      for (final r in results) {
        final cover = r['cover_image'] as String?;
        if (cover == null || cover.isEmpty) continue;

        final coverUri = Uri.tryParse(cover);
        if (coverUri == null) continue;

        final title = r['title'] as String?;
        out.add(
          CoverCandidate(
            provider: 'Discogs',
            title: title ?? album,
            subtitle: artist,
            imageUrl: coverUri,
          ),
        );
      }
      return out;
    } catch (e) {
      _logOnce('Discogs candidate search failed', e);
      return const [];
    }
  }

  static Future<List<CoverCandidate>> _searchDeezerCandidates({
    required String artist,
    required String album,
  }) async {
    try {
      final uri = Uri.https('api.deezer.com', '/search/album', {
        'q': '$artist $album',
        'limit': '25',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (decoded['data'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (data.isEmpty) return const [];

      final out = <CoverCandidate>[];
      for (final r in data) {
        final cover = (r['cover_big'] as String?) ?? (r['cover_medium'] as String?);
        if (cover == null || cover.isEmpty) continue;

        final title = r['title'] as String?;
        final artistObj = r['artist'] as Map<String, dynamic>?;
        final artistName = artistObj?['name'] as String?;

        out.add(
          CoverCandidate(
            provider: 'Deezer',
            title: title ?? album,
            subtitle: artistName ?? artist,
            imageUrl: Uri.parse(cover),
          ),
        );
      }

      return out;
    } catch (e) {
      _logOnce('Deezer candidate search failed', e);
      return const [];
    }
  }

  static Future<List<CoverCandidate>> _searchITunesCandidates({
    required String artist,
    required String album,
  }) async {
    try {
      final term = '$artist $album';
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': term,
        'entity': 'album',
        'limit': '10',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (results.isEmpty) return const [];

      final out = <CoverCandidate>[];
      for (final r in results) {
        final artwork = r['artworkUrl100'] as String?;
        final collection = r['collectionName'] as String?;
        final artistName = r['artistName'] as String?;

        if (artwork == null || artwork.isEmpty) continue;

        final hiRes = artwork.replaceAll('100x100bb.jpg', '600x600bb.jpg');

        out.add(
          CoverCandidate(
            provider: 'iTunes',
            title: collection ?? album,
            subtitle: artistName ?? artist,
            imageUrl: Uri.parse(hiRes),
          ),
        );
      }
      return out;
    } catch (e) {
      _logOnce('iTunes candidate search failed', e);
      return const [];
    }
  }

  static Future<String?> _fetchViaCoverArtArchive({
    required String artist,
    required String album,
  }) async {
    try {
      final query = 'release:"$album" AND artist:"$artist"';

      final uri = Uri.https('musicbrainz.org', '/ws/2/release/', {
        'query': query,
        'fmt': 'json',
        'limit': '5',
      });

      final resp = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'GhostMusic/1.0 (contact: dev@local)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final releases = (decoded['releases'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (releases.isEmpty) return null;

      final key = _cacheKey(artist: artist, album: album);

      for (final release in releases) {
        final mbid = release['id'] as String?;
        if (mbid == null || mbid.isEmpty) continue;

        final coverUri = Uri.https('coverartarchive.org', '/release/$mbid/front-500');
        final coverResp = await http
            .get(
              coverUri,
              headers: {
                'User-Agent': 'GhostMusic/1.0 (contact: dev@local)',
                'Accept': 'image/*',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (coverResp.statusCode != 200 || coverResp.bodyBytes.isEmpty) {
          continue;
        }

        return _writeCached(
          key,
          coverResp.bodyBytes,
          contentType: coverResp.headers['content-type'],
        );
      }

      return null;
    } catch (e) {
      _logOnce('CAA cover fetch failed', e);
      return null;
    }
  }

  static Future<String?> _getDiscogsToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('discogs_token');
      if (token == null) return null;
      final trimmed = token.trim();
      if (trimmed.isEmpty) return null;
      return trimmed;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchViaDiscogs({
    required String artist,
    required String album,
    required String token,
  }) async {
    try {
      final uri = Uri.https('api.discogs.com', '/database/search', {
        'type': 'release',
        'per_page': '1',
        'artist': artist,
        'release_title': album,
      });

      final resp = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'GhostMusic/1.0 (contact: dev@local)',
              'Accept': 'application/json',
              'Authorization': 'Discogs token=$token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (results.isEmpty) return null;

      final coverUrl = results.first['cover_image'] as String?;
      if (coverUrl == null || coverUrl.isEmpty) return null;

      final coverUri = Uri.tryParse(coverUrl);
      if (coverUri == null) return null;

      final imageResp = await http
          .get(coverUri, headers: {
            'User-Agent': 'GhostMusic/1.0',
            'Accept': 'image/*',
          })
          .timeout(const Duration(seconds: 12));

      if (imageResp.statusCode != 200 || imageResp.bodyBytes.isEmpty) return null;

      final key = _cacheKey(artist: artist, album: album);
      return _writeCached(
        key,
        imageResp.bodyBytes,
        contentType: imageResp.headers['content-type'],
      );
    } catch (e) {
      _logOnce('Discogs cover fetch failed', e);
      return null;
    }
  }

  static Future<String?> _fetchViaDeezer({
    required String artist,
    required String album,
  }) async {
    try {
      final uri = Uri.https('api.deezer.com', '/search/album', {
        'q': '$artist $album',
        'limit': '1',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (decoded['data'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (data.isEmpty) return null;

      final cover = (data.first['cover_big'] as String?) ?? (data.first['cover_medium'] as String?);
      if (cover == null || cover.isEmpty) return null;

      final imageResp = await http.get(Uri.parse(cover), headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'image/*',
      }).timeout(const Duration(seconds: 12));

      if (imageResp.statusCode != 200 || imageResp.bodyBytes.isEmpty) return null;

      final key = _cacheKey(artist: artist, album: album);
      return _writeCached(
        key,
        imageResp.bodyBytes,
        contentType: imageResp.headers['content-type'],
      );
    } catch (e) {
      _logOnce('Deezer cover fetch failed', e);
      return null;
    }
  }

  static Future<String?> _fetchViaITunes({
    required String artist,
    required String album,
  }) async {
    try {
      final term = '$artist $album';
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': term,
        'entity': 'album',
        'limit': '1',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return null;

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (results.isEmpty) return null;

      final artwork = results.first['artworkUrl100'] as String?;
      if (artwork == null || artwork.isEmpty) return null;

      // Upgrade size when possible.
      final hiRes = artwork.replaceAll('100x100bb.jpg', '600x600bb.jpg');
      final imageResp = await http.get(Uri.parse(hiRes), headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'image/*',
      }).timeout(const Duration(seconds: 20));

      if (imageResp.statusCode != 200 || imageResp.bodyBytes.isEmpty) return null;

      final key = _cacheKey(artist: artist, album: album);
      return _writeCached(
        key,
        imageResp.bodyBytes,
        contentType: imageResp.headers['content-type'],
      );
    } catch (e) {
      _logOnce('iTunes cover fetch failed', e);
      return null;
    }
  }

  static Future<String?> _fetchViaWikimedia({
    required String artist,
    required String album,
  }) async {
    try {
      final candidates = await _searchWikimediaCandidates(
        query: '$artist $album album cover',
        subtitle: artist,
        title: album,
      );
      if (candidates.isEmpty) return null;

      final imageUri = candidates.first.imageUrl;
      final imageResp = await http.get(imageUri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'image/*',
      }).timeout(const Duration(seconds: 15));

      if (imageResp.statusCode != 200 || imageResp.bodyBytes.isEmpty) return null;

      final key = _cacheKey(artist: artist, album: album);
      return _writeCached(
        key,
        imageResp.bodyBytes,
        contentType: imageResp.headers['content-type'],
      );
    } catch (e) {
      _logOnce('Wikimedia cover fetch failed', e);
      return null;
    }
  }

  // ==================== NEW SOURCES ====================

  /// Search for cover art using Last.fm API (free, no key required for basic search)
  static Future<List<CoverCandidate>> _searchLastFmCandidates({
    required String artist,
    required String album,
  }) async {
    try {
      // Try the direct album page first
      final albumUri = Uri.https('www.last.fm', '/music/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(album)}/+images');
      
      final resp = await http.get(albumUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return const [];

      final body = resp.body;
      final candidates = <CoverCandidate>[];

      // Parse image URLs from Last.fm page (look for ar0 class images - album art)
      final imgRegex = RegExp(r'https://lastfm\.freetls\.fastly\.net/i/u/[^"]+');
      final matches = imgRegex.allMatches(body);

      final seen = <String>{};
      for (final match in matches) {
        var imgUrl = match.group(0);
        if (imgUrl == null) continue;
        
        // Skip small images and duplicates
        if (imgUrl.contains('/34s/') || imgUrl.contains('/64s/') || imgUrl.contains('/avatar')) continue;
        
        // Upgrade to large size (300x300 or larger)
        imgUrl = imgUrl.replaceAll(RegExp(r'/\d+s/'), '/300x300/');
        
        if (!seen.add(imgUrl)) continue;
        
        candidates.add(CoverCandidate(
          provider: 'Last.fm',
          title: album,
          subtitle: artist,
          imageUrl: Uri.parse(imgUrl),
          thumbnailUrl: imgUrl.replaceAll('/300x300/', '/174s/'),
        ));
        
        if (candidates.length >= 8) break;
      }

      return candidates;
    } catch (e) {
      _logOnce('Last.fm candidate search failed', e);
      return const [];
    }
  }

  /// Fetch cover art via Last.fm
  static Future<String?> _fetchViaLastFm({
    required String artist,
    required String album,
  }) async {
    try {
      final candidates = await _searchLastFmCandidates(artist: artist, album: album);
      if (candidates.isEmpty) return null;

      // Try to download the first candidate
      final imageUrl = candidates.first.imageUrl.toString().replaceAll('/300x300/', '/770x0/');
      final imageResp = await http.get(Uri.parse(imageUrl), headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'image/*',
      }).timeout(const Duration(seconds: 15));

      if (imageResp.statusCode != 200 || imageResp.bodyBytes.isEmpty) return null;

      final key = _cacheKey(artist: artist, album: album);
      return _writeCached(
        key,
        imageResp.bodyBytes,
        contentType: imageResp.headers['content-type'],
      );
    } catch (e) {
      _logOnce('Last.fm cover fetch failed', e);
      return null;
    }
  }

  /// Search for cover art using Spotify embed (no API key required)
  static Future<List<CoverCandidate>> _searchSpotifyCandidates({
    required String artist,
    required String album,
  }) async {
    try {
      // Use Spotify's search through their web player (no auth needed for basic search)
      final query = Uri.encodeComponent('$artist $album');
      final uri = Uri.https('open.spotify.com', '/search/$query');
      
      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return const [];

      final body = resp.body;
      final candidates = <CoverCandidate>[];

      // Parse Spotify image URLs (i.scdn.co)
      final imgRegex = RegExp(r'https://i\.scdn\.co/image/[a-zA-Z0-9]+');
      final matches = imgRegex.allMatches(body);

      final seen = <String>{};
      for (final match in matches) {
        final imgUrl = match.group(0);
        if (imgUrl == null || !seen.add(imgUrl)) continue;

        candidates.add(CoverCandidate(
          provider: 'Spotify',
          title: album,
          subtitle: artist,
          imageUrl: Uri.parse(imgUrl),
        ));
        
        if (candidates.length >= 10) break;
      }

      return candidates;
    } catch (e) {
      _logOnce('Spotify candidate search failed', e);
      return const [];
    }
  }

  /// Search for cover art using SoundCloud.
  ///
  /// Supports direct SoundCloud URLs via oEmbed, and plain text queries via the
  /// public search page (best effort; no API key).
  static Future<List<CoverCandidate>> _searchSoundCloudCandidates({
    required String query,
    String? subtitle,
  }) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) return const [];

      final maybeUrl = Uri.tryParse(trimmed);
      if (maybeUrl != null &&
          (maybeUrl.isScheme('http') || maybeUrl.isScheme('https')) &&
          maybeUrl.host.toLowerCase().contains('soundcloud.com')) {
        return _searchSoundCloudOEmbed(maybeUrl);
      }

      final searchUri = Uri.https('soundcloud.com', '/search', {'q': trimmed});
      final resp = await http.get(searchUri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return const [];

      final body = resp.body;
      final candidates = <CoverCandidate>[];
      final seen = <String>{};

      // Try direct image URLs.
      final directRegex = RegExp('https?:\\/\\/i1\\.sndcdn\\.com\\/artworks-[^"\\\'\\s]+');
      for (final match in directRegex.allMatches(body)) {
        final url = match.group(0);
        if (url == null || !seen.add(url)) continue;

        final imgUri = Uri.tryParse(url);
        if (imgUri == null) continue;

        candidates.add(CoverCandidate(
          provider: 'SoundCloud',
          title: trimmed,
          subtitle: subtitle ?? 'SoundCloud',
          imageUrl: imgUri,
        ));

        if (candidates.length >= 12) break;
      }

      // Try escaped URLs (https:\/\/i1.sndcdn.com\/artworks-...)
      if (candidates.isEmpty) {
        final escapedRegex = RegExp(r'https:\\/\\/i1\.sndcdn\.com\\/artworks-[^"\\]+');
        for (final match in escapedRegex.allMatches(body)) {
          final raw = match.group(0);
          if (raw == null) continue;

          final url = raw.replaceAll('\\/', '/').replaceAll('\\\\', '');
          if (!seen.add(url)) continue;

          final imgUri = Uri.tryParse(url);
          if (imgUri == null) continue;

          candidates.add(CoverCandidate(
            provider: 'SoundCloud',
            title: trimmed,
            subtitle: subtitle ?? 'SoundCloud',
            imageUrl: imgUri,
          ));

          if (candidates.length >= 12) break;
        }
      }

      return candidates;
    } catch (e) {
      _logOnce('SoundCloud candidate search failed', e);
      return const [];
    }
  }

  static Future<List<CoverCandidate>> _searchSoundCloudOEmbed(Uri soundcloudUrl) async {
    try {
      final oembedUri = Uri.https('soundcloud.com', '/oembed', {
        'format': 'json',
        'url': soundcloudUrl.toString(),
      });

      final resp = await http.get(oembedUri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final thumb = decoded['thumbnail_url'] as String?;
      if (thumb == null || thumb.trim().isEmpty) return const [];

      final title = (decoded['title'] as String?)?.trim();

      var imgUrl = thumb.trim();
      // Prefer higher-res square variants when available.
      imgUrl = imgUrl
          .replaceAll('-large.', '-t500x500.')
          .replaceAll('-t300x300.', '-t500x500.');

      final imgUri = Uri.tryParse(imgUrl) ?? Uri.tryParse(thumb.trim());
      if (imgUri == null) return const [];

      return [
        CoverCandidate(
          provider: 'SoundCloud',
          title: title?.isNotEmpty == true ? title! : soundcloudUrl.toString(),
          subtitle: 'SoundCloud',
          imageUrl: imgUri,
        ),
      ];
    } catch (e) {
      _logOnce('SoundCloud oEmbed failed', e);
      return const [];
    }
  }

  /// Search for album art images using Bing Images (web search fallback)
  static Future<List<CoverCandidate>> _searchBingImagesCandidates({
    required String query,
    String? subtitle,
  }) async {
    try {
      final uri = Uri.https('www.bing.com', '/images/search', {
        'q': '$query album cover',
        'qft': '+filterui:aspect-square+filterui:imagesize-large',
        'form': 'IRFLTR',
        'first': '1',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return const [];

      final body = resp.body;
      final candidates = <CoverCandidate>[];

      // Parse image URLs from Bing results (murl parameter contains full-size image)
      final murlRegex = RegExp(r'murl&quot;:&quot;([^&]+)&quot;');
      final matches = murlRegex.allMatches(body);

      final seen = <String>{};
      for (final match in matches) {
        var imgUrl = match.group(1);
        if (imgUrl == null) continue;
        
        // Decode URL
        imgUrl = Uri.decodeComponent(imgUrl);
        
        if (!seen.add(imgUrl)) continue;

        final imgUri = Uri.tryParse(imgUrl);
        if (imgUri == null || !(imgUri.isScheme('http') || imgUri.isScheme('https'))) {
          continue;
        }

        // Skip very small images and non-standard domains
        if (imgUrl.contains('favicon') || imgUrl.contains('logo')) continue;

        candidates.add(CoverCandidate(
          provider: 'Bing Images',
          title: query,
          subtitle: subtitle ?? 'Web Search',
          imageUrl: imgUri,
        ));
        
        if (candidates.length >= 12) break;
      }

      return candidates;
    } catch (e) {
      _logOnce('Bing Images candidate search failed', e);
      return const [];
    }
  }

  /// Search for cover art using Wikimedia Commons (no key; best-effort).
  static Future<List<CoverCandidate>> _searchWikimediaCandidates({
    required String query,
    String? subtitle,
    String? title,
  }) async {
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'generator': 'search',
        'gsrsearch': query,
        'gsrlimit': '12',
        'prop': 'pageimages|info',
        'pithumbsize': '600',
        'inprop': 'url',
        'origin': '*',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'GhostMusic/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return const [];

      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final queryObj = decoded['query'] as Map<String, dynamic>?;
      final pages = queryObj?['pages'];
      if (pages is! Map) return const [];

      final out = <CoverCandidate>[];
      final seen = <String>{};

      for (final entry in pages.entries) {
        final page = entry.value;
        if (page is! Map) continue;

        final pageTitle = (page['title'] as String?)?.trim();
        final thumb = page['thumbnail'];
        final thumbUrl = (thumb is Map) ? (thumb['source'] as String?) : null;

        final imgUrl = thumbUrl;
        if (imgUrl == null || imgUrl.isEmpty) continue;
        if (!seen.add(imgUrl)) continue;

        final imgUri = Uri.tryParse(imgUrl);
        if (imgUri == null) continue;

        out.add(
          CoverCandidate(
            provider: 'Wikimedia',
            title: title ?? (pageTitle?.isNotEmpty == true ? pageTitle! : query),
            subtitle: subtitle ?? 'Wikimedia Commons',
            imageUrl: imgUri,
            thumbnailUrl: imgUrl,
          ),
        );

        if (out.length >= 12) break;
      }

      return out;
    } catch (e) {
      _logOnce('Wikimedia candidate search failed', e);
      return const [];
    }
  }

  /// Search for album art images using DuckDuckGo Images (privacy-friendly alternative)
  static Future<List<CoverCandidate>> _searchDuckDuckGoCandidates({
    required String query,
    String? subtitle,
  }) async {
    try {
      // DuckDuckGo uses a token-based system, so we use their instant answer API
      // First get vqd token
      final tokenUri = Uri.https('duckduckgo.com', '/', {'q': '$query album cover'});
      final tokenResp = await http.get(tokenUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 10));

      if (tokenResp.statusCode != 200) return const [];

      // Extract vqd token (DuckDuckGo changes this often; best-effort).
      final body = tokenResp.body;
      final vqd = RegExp(r'vqd=([^&"]+)').firstMatch(body)?.group(1) ??
          RegExp(r"vqd='([^']+)'", caseSensitive: false).firstMatch(body)?.group(1) ??
          RegExp(r'vqd="([^"]+)"', caseSensitive: false).firstMatch(body)?.group(1);
      if (vqd == null || vqd.trim().isEmpty) return const [];

      // Search images
      final uri = Uri.https('duckduckgo.com', '/i.js', {
        'l': 'us-en',
        'o': 'json',
        'q': '$query album cover',
        'vqd': vqd.trim(),
        'f': ',size:Large,type:photo,layout:Square',
        'p': '1',
      });

      final resp = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return const [];

      final candidates = <CoverCandidate>[];

      try {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final results = (decoded['results'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        for (final r in results) {
          final imgUrl = r['image'] as String?;
          final thumbUrl = r['thumbnail'] as String?;
          final title = r['title'] as String?;
          final width = r['width'] as int?;
          final height = r['height'] as int?;

          if (imgUrl == null || imgUrl.isEmpty) continue;

          final imgUri = Uri.tryParse(imgUrl);
          if (imgUri == null) continue;

          candidates.add(CoverCandidate(
            provider: 'DuckDuckGo',
            title: title ?? query,
            subtitle: subtitle ?? 'Web Search',
            imageUrl: imgUri,
            thumbnailUrl: thumbUrl,
            width: width,
            height: height,
          ));
          
          if (candidates.length >= 15) break;
        }
      } catch (_) {
        // JSON parsing failed, return empty
      }

      return candidates;
    } catch (e) {
      _logOnce('DuckDuckGo candidate search failed', e);
      return const [];
    }
  }

  /// Search by track title (fallback when album is not available)
  static Future<List<CoverCandidate>> searchByTrackTitle({
    required String artist,
    required String title,
  }) async {
    final candidates = <CoverCandidate>[];
    final query = '$artist $title';

    // Try multiple sources in parallel for speed
    final futures = await Future.wait([
      _searchITunesCandidates(artist: artist, album: title),
      _searchDeezerCandidates(artist: artist, album: title),
      _searchDuckDuckGoCandidates(query: query, subtitle: artist),
      _searchBingImagesCandidates(query: query, subtitle: artist),
      _searchWikimediaCandidates(query: '$query album cover', subtitle: artist, title: title),
    ]);

    for (final list in futures) {
      candidates.addAll(list);
    }

    // De-dup by url
    final seen = <String>{};
    final out = <CoverCandidate>[];
    for (final c in candidates) {
      final k = c.imageUrl.toString();
      if (seen.add(k)) out.add(c);
    }

    return out;
  }

  /// Custom search - allows user to specify any search query
  static Future<List<CoverCandidate>> searchCustom(String query) async {
    final candidates = <CoverCandidate>[];

    // Try multiple image search engines in parallel
    final futures = await Future.wait([
      _searchSoundCloudCandidates(query: query),
      _searchDuckDuckGoCandidates(query: query),
      _searchBingImagesCandidates(query: query),
      _searchWikimediaCandidates(query: query, subtitle: 'Custom'),
      // Also try music-specific sources
      _searchITunesCandidates(artist: '', album: query),
      _searchDeezerCandidates(artist: '', album: query),
    ]);

    for (final list in futures) {
      candidates.addAll(list);
    }

    // De-dup by url
    final seen = <String>{};
    final out = <CoverCandidate>[];
    for (final c in candidates) {
      final k = c.imageUrl.toString();
      if (seen.add(k)) out.add(c);
    }

    return out;
  }

  /// Save a cover image from any URL (for use with custom search)
  static Future<String?> saveCustomCover({
    required String trackPath,
    required Uri imageUrl,
  }) async {
    try {
      final meta = await MetadataService.enrichTrack(Track(filePath: trackPath));

      String? artist = meta.track.artist;
      String? album = meta.track.album;

      // If tags are missing, try to infer from folder structure
      if ((artist == null || artist.trim().isEmpty) || (album == null || album.trim().isEmpty)) {
        final guess = _guessArtistAlbum(trackPath);
        artist = artist?.trim().isNotEmpty == true ? artist : guess.$1;
        album = album?.trim().isNotEmpty == true ? album : guess.$2;
      }

      // If we still don't have reliable artist/album, save as a per-track override.
      if (artist == null || artist.trim().isEmpty || album == null || album.trim().isEmpty) {
        return saveOverrideForTrackFromUrl(trackPath: trackPath, imageUrl: imageUrl);
      }

      return saveOverrideFromUrl(artist: artist, album: album, imageUrl: imageUrl);
    } catch (e) {
      _logOnce('saveCustomCover failed', e);
      return null;
    }
  }

  static String? _extFromPathHint(String? hintPath) {
    if (hintPath == null) return null;
    final ext = p.extension(hintPath).toLowerCase();
    if (ext == '.png') return '.png';
    if (ext == '.jpg' || ext == '.jpeg') return '.jpg';
    return null;
  }

  static Future<String?> _saveOverrideBytes({
    required String prefix,
    required String key,
    required Uint8List bytes,
    String? contentType,
    String? hintPath,
  }) async {
    try {
      if (bytes.isEmpty) return null;

      final dir = await _overridesDir();
      final ext = _extFromContentTypeOrMagic(contentType, bytes) ?? _extFromPathHint(hintPath) ?? '.jpg';
      final normalizedExt = ext == '.png' ? '.png' : '.jpg';

      // Clear old files (jpg/png)
      final oldJpg = File(p.join(dir.path, '${prefix}_$key.jpg'));
      final oldPng = File(p.join(dir.path, '${prefix}_$key.png'));
      if (await oldJpg.exists()) await oldJpg.delete();
      if (await oldPng.exists()) await oldPng.delete();

      final out = File(p.join(dir.path, '${prefix}_$key$normalizedExt'));
      await out.writeAsBytes(bytes, flush: true);
      return out.path;
    } catch (e) {
      _logOnce('_saveOverrideBytes failed', e);
      return null;
    }
  }

  /// Save a cover image from a local file path.
  ///
  /// This is the fastest & most reliable fallback when online sources are not available.
  static Future<String?> saveCustomCoverFromFile({
    required String trackPath,
    required String imagePath,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final meta = await MetadataService.enrichTrack(Track(filePath: trackPath));

      String? artist = meta.track.artist;
      String? album = meta.track.album;

      // If tags are missing, try to infer from folder structure
      if ((artist == null || artist.trim().isEmpty) || (album == null || album.trim().isEmpty)) {
        final guess = _guessArtistAlbum(trackPath);
        artist = artist?.trim().isNotEmpty == true ? artist : guess.$1;
        album = album?.trim().isNotEmpty == true ? album : guess.$2;
      }

      // If we still don't have reliable artist/album, save as a per-track override.
      if (artist == null || artist.trim().isEmpty || album == null || album.trim().isEmpty) {
        final key = _trackOverrideKey(trackPath);
        return _saveOverrideBytes(prefix: 'trk', key: key, bytes: bytes, hintPath: imagePath);
      }

      final key = _cacheKey(artist: artist, album: album);
      return _saveOverrideBytes(prefix: 'ov', key: key, bytes: bytes, hintPath: imagePath);
    } catch (e) {
      _logOnce('saveCustomCoverFromFile failed', e);
      return null;
    }
  }

  // ignore: unused_element
  static Future<String?> _saveOverrideFromUrlWithKey({
    required String key,
    required Uri imageUrl,
  }) async {
    try {
      final resp = await http
          .get(imageUrl, headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'image/*',
          })
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

      final dir = await _overridesDir();
      final ext = _extFromContentTypeOrMagic(resp.headers['content-type'], resp.bodyBytes) ?? '.jpg';

      // Clear old files
      final oldJpg = File(p.join(dir.path, 'ov_$key.jpg'));
      final oldPng = File(p.join(dir.path, 'ov_$key.png'));
      if (await oldJpg.exists()) await oldJpg.delete();
      if (await oldPng.exists()) await oldPng.delete();

      final out = File(p.join(dir.path, 'ov_$key$ext'));
      await out.writeAsBytes(resp.bodyBytes, flush: true);
      return out.path;
    } catch (e) {
      _logOnce('_saveOverrideFromUrlWithKey failed', e);
      return null;
    }
  }
}
