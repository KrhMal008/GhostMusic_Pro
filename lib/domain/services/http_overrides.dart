import 'dart:io';

import 'package:flutter/foundation.dart';

/// Centralized HTTP overrides for Windows dev environments.
///
/// Goals:
/// - Support proxies (common on Windows / corp networks).
/// - Allow bad certs only in debug, and only for a safe host allowlist.
class GhostHttpOverrides extends HttpOverrides {
  static const Set<String> _allowBadCertHosts = <String>{
    'musicbrainz.org',
    'coverartarchive.org',
    'www.last.fm',
    'last.fm',
    'lastfm.freetls.fastly.net',
    'api.deezer.com',
    'itunes.apple.com',
    'api.discogs.com',
    'duckduckgo.com',
    'www.bing.com',
    'commons.wikimedia.org',
  };

  static String? _proxyRule; // e.g. "PROXY 127.0.0.1:7890; DIRECT"

  static void installForWindowsDebug() {
    if (!Platform.isWindows) return;
    if (!kDebugMode) return;
    HttpOverrides.global = GhostHttpOverrides();
  }

  /// Accepts user input like:
  /// - "127.0.0.1:7890"
  /// - "http://127.0.0.1:7890"
  /// - "PROXY 127.0.0.1:7890; DIRECT"
  static void setProxyFromUserInput(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) {
      _proxyRule = null;
      return;
    }

    if (v.toUpperCase().startsWith('PROXY ') || v.toUpperCase().contains('DIRECT')) {
      _proxyRule = v;
      return;
    }

    final cleaned = v
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceAll('/', '');

    _proxyRule = 'PROXY $cleaned; DIRECT';
  }

  static String? get proxyRule => _proxyRule;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // Proxy: user-configured first, else environment variables.
    client.findProxy = (uri) {
      final rule = _proxyRule;
      if (rule != null && rule.trim().isNotEmpty) return rule;
      return HttpClient.findProxyFromEnvironment(uri, environment: Platform.environment);
    };

    // Bad certs: only in debug and only for allowlist.
    if (kDebugMode && Platform.isWindows) {
      client.badCertificateCallback = (cert, host, port) {
        return _allowBadCertHosts.contains(host);
      };
    }

    // Fail faster instead of hanging forever (per-request timeouts still apply).
    client.connectionTimeout = const Duration(seconds: 10);

    return client;
  }
}
