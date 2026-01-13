import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

enum FolderArtMode {
  auto,
  collage,
  imageFile,
  track,
}

@immutable
class FolderArtOverride {
  final FolderArtMode mode;
  final String? value;

  const FolderArtOverride({required this.mode, this.value});

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'value': value,
    };
  }

  static FolderArtOverride? fromJson(Map<String, dynamic> json) {
    final rawMode = (json['mode'] as String?)?.trim();
    if (rawMode == null || rawMode.isEmpty) return null;

    FolderArtMode? mode;
    for (final m in FolderArtMode.values) {
      if (m.name == rawMode) {
        mode = m;
        break;
      }
    }
    if (mode == null) return null;

    final value = (json['value'] as String?)?.trim();
    return FolderArtOverride(mode: mode, value: value?.isEmpty == true ? null : value);
  }
}

class FolderArtService {
  FolderArtService._();

  static const _prefsKey = 'folder_art_overrides_v1';

  static bool _loaded = false;
  static final Map<String, FolderArtOverride> _map = <String, FolderArtOverride>{};

  static String _keyForFolder(String folderPath) {
    return p.normalize(folderPath).toLowerCase();
  }

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
        final key = entry.key;
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final parsed = FolderArtOverride.fromJson(value);
          if (parsed != null) _map[key] = parsed;
        } else if (value is Map) {
          final parsed = FolderArtOverride.fromJson(value.cast<String, dynamic>());
          if (parsed != null) _map[key] = parsed;
        }
      }
    } catch (_) {
      // ignore corrupted json
    }

    _loaded = true;
  }

  static Future<FolderArtOverride?> getForFolder(String folderPath) async {
    await _ensureLoaded();
    return _map[_keyForFolder(folderPath)];
  }

  static Future<void> setForFolder(String folderPath, FolderArtOverride override) async {
    await _ensureLoaded();

    final key = _keyForFolder(folderPath);

    if (override.mode == FolderArtMode.auto) {
      _map.remove(key);
    } else {
      _map[key] = override;
    }

    await _persist();
  }

  static Future<void> clearForFolder(String folderPath) async {
    await _ensureLoaded();
    _map.remove(_keyForFolder(folderPath));
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
