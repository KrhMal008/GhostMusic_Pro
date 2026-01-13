import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class TrackTagOverride {
  final String? title;
  final String? artist;
  final String? album;

  const TrackTagOverride({this.title, this.artist, this.album});

  bool get isEmpty {
    return (title == null || title!.trim().isEmpty) &&
        (artist == null || artist!.trim().isEmpty) &&
        (album == null || album!.trim().isEmpty);
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
    };
  }

  static TrackTagOverride fromJson(Map<String, dynamic> json) {
    return TrackTagOverride(
      title: (json['title'] as String?)?.trim(),
      artist: (json['artist'] as String?)?.trim(),
      album: (json['album'] as String?)?.trim(),
    );
  }
}

class TagOverrideService {
  TagOverrideService._();

  static const _prefsKey = 'track_tag_overrides_v1';

  static bool _loaded = false;
  static final Map<String, TrackTagOverride> _map = <String, TrackTagOverride>{};

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _loaded = true;
        return;
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _map[entry.key] = TrackTagOverride.fromJson(value);
        } else if (value is Map) {
          _map[entry.key] = TrackTagOverride.fromJson(value.cast<String, dynamic>());
        }
      }
    } catch (_) {
      // ignore corrupted json
    }

    _loaded = true;
  }

  static Future<TrackTagOverride?> getForFile(String filePath) async {
    await _ensureLoaded();
    return _map[filePath];
  }

  static Future<void> setForFile(String filePath, TrackTagOverride override) async {
    await _ensureLoaded();

    if (override.isEmpty) {
      _map.remove(filePath);
    } else {
      _map[filePath] = override;
    }

    await _persist();
  }

  static Future<void> clearForFile(String filePath) async {
    await _ensureLoaded();
    _map.remove(filePath);
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = <String, dynamic>{};
      for (final e in _map.entries) {
        encoded[e.key] = e.value.toJson();
      }
      await prefs.setString(_prefsKey, jsonEncode(encoded));
    } catch (_) {}
  }
}
