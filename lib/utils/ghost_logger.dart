import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Log levels for GhostLogger
enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// A robust file + console logger for Ghost Music.
/// 
/// Features:
/// - Async-safe write queue
/// - Automatic file rotation (by date, size, count)
/// - Persistent log mode toggle
/// - Session headers
class GhostLogger {
  GhostLogger._();

  static GhostLogger? _instance;
  static GhostLogger get instance => _instance ??= GhostLogger._();

  static const String _logModeKey = 'ghost_log_mode_enabled';
  static const int _maxFileSizeBytes = 3 * 1024 * 1024; // 3MB
  static const int _maxLogFiles = 10;
  static const String _logFilePrefix = 'ghostmusic_log_';

  bool _initialized = false;
  bool _logModeEnabled = kDebugMode; // Default: enabled in debug
  Directory? _logDir;
  File? _currentLogFile;
  int _currentFileSuffix = 1;
  String _currentDateStr = '';

  final Queue<String> _writeQueue = Queue<String>();
  bool _isWriting = false;
  Completer<void>? _writeCompleter;

  // Recent lines buffer for quick copy
  final List<String> _recentLines = [];
  static const int _recentLinesMax = 500;

  /// Initialize the logger. Call early in main().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Load log mode preference
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_logModeKey);
      _logModeEnabled = stored ?? kDebugMode;

      // Get log directory
      final appSupport = await getApplicationSupportDirectory();
      _logDir = Directory(p.join(appSupport.path, 'logs'));
      if (!await _logDir!.exists()) {
        await _logDir!.create(recursive: true);
      }

      // Clean old logs
      await _cleanOldLogs();

      // Open today's log file
      await _openTodayLogFile();

      // Log session start
      _logSessionHeader();
    } catch (e) {
      debugPrint('GhostLogger init failed: $e');
    }
  }

  /// Enable or disable log mode
  Future<void> setLogModeEnabled(bool enabled) async {
    _logModeEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_logModeKey, enabled);
    } catch (_) {}

    info('LogMode', 'Log mode ${enabled ? "enabled" : "disabled"}');
  }

  /// Check if log mode is enabled
  bool get isLogModeEnabled => _logModeEnabled;

  /// Log a debug message
  void debug(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Log an info message
  void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log a warning message
  void warn(String tag, String message) {
    _log(LogLevel.warn, tag, message);
  }

  /// Log an error message with optional stack trace
  void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    final errorStr = error != null ? '\n  Error: $error' : '';
    final stackStr = stackTrace != null ? '\n  Stack: ${_formatStackTrace(stackTrace)}' : '';
    _log(LogLevel.error, tag, '$message$errorStr$stackStr');
  }

  /// Log a playback event (convenience method)
  void playback(String action, {
    String? trackPath,
    String? trackTitle,
    String? trackArtist,
    int? queueIndex,
    int? queueLength,
    Duration? position,
    Duration? duration,
    Map<String, dynamic>? extra,
  }) {
    final parts = <String>[action];
    
    if (trackTitle != null) parts.add('title="$trackTitle"');
    if (trackArtist != null) parts.add('artist="$trackArtist"');
    if (trackPath != null) parts.add('path="${_truncatePath(trackPath)}"');
    if (queueIndex != null && queueLength != null) parts.add('queue=$queueIndex/$queueLength');
    if (position != null) parts.add('pos=${position.inMilliseconds}ms');
    if (duration != null) parts.add('dur=${duration.inMilliseconds}ms');
    
    if (extra != null) {
      for (final entry in extra.entries) {
        parts.add('${entry.key}=${entry.value}');
      }
    }

    info('Playback', parts.join(' | '));
  }

  /// Log a UI event
  void ui(String component, String action, [Map<String, dynamic>? details]) {
    final detailsStr = details != null 
        ? ' | ${details.entries.map((e) => '${e.key}=${e.value}').join(' ')}'
        : '';
    debug('UI', '$component: $action$detailsStr');
  }

  /// Get the path to the current log file
  String? get currentLogFilePath => _currentLogFile?.path;

  /// Get paths to all log files (most recent first)
  Future<List<String>> getLogFilePaths() async {
    if (_logDir == null) return [];

    try {
      final files = await _logDir!.list().toList();
      final logFiles = files
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(_logFilePrefix))
          .toList();

      // Sort by modification time, newest first
      logFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return logFiles.map((f) => f.path).toList();
    } catch (e) {
      debugPrint('Failed to list log files: $e');
      return [];
    }
  }

  /// Get recent log lines (for quick copy)
  List<String> getRecentLines([int count = 200]) {
    final start = _recentLines.length > count ? _recentLines.length - count : 0;
    return _recentLines.sublist(start);
  }

  /// Get combined content of recent log files
  Future<String> getRecentLogsContent({int maxFiles = 2}) async {
    final paths = await getLogFilePaths();
    final buffer = StringBuffer();

    for (var i = 0; i < paths.length && i < maxFiles; i++) {
      try {
        final file = File(paths[i]);
        final content = await file.readAsString();
        buffer.writeln('=== ${p.basename(paths[i])} ===');
        buffer.writeln(content);
        buffer.writeln();
      } catch (e) {
        buffer.writeln('=== Failed to read ${p.basename(paths[i])}: $e ===');
      }
    }

    return buffer.toString();
  }

  // --- Private methods ---

  void _log(LogLevel level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(5);
    final platform = _platformName;
    final line = '[$timestamp] [$levelStr] [$platform] [$tag] $message';

    // Always print to console
    debugPrint(line);

    // Add to recent lines buffer
    _recentLines.add(line);
    if (_recentLines.length > _recentLinesMax) {
      _recentLines.removeAt(0);
    }

    // Write to file if log mode enabled
    if (_logModeEnabled && _currentLogFile != null) {
      _enqueueWrite('$line\n');
    }
  }

  void _logSessionHeader() {
    final now = DateTime.now();
    final header = '''

════════════════════════════════════════════════════════════════
  GHOST MUSIC SESSION STARTED
  Time: ${now.toIso8601String()}
  Platform: $_platformName
  Debug mode: $kDebugMode
  Log mode: $_logModeEnabled
════════════════════════════════════════════════════════════════
''';
    
    if (_logModeEnabled && _currentLogFile != null) {
      _enqueueWrite(header);
    }
    debugPrint(header);
  }

  String get _platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  String _truncatePath(String path) {
    if (path.length <= 60) return path;
    final fileName = p.basename(path);
    if (fileName.length >= 50) {
      return '.../${fileName.substring(0, 47)}...';
    }
    return '.../${fileName}';
  }

  String _formatStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    // Take first 5 lines only
    final limited = lines.take(5).join('\n    ');
    return limited;
  }

  Future<void> _openTodayLogFile() async {
    if (_logDir == null) return;

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // If date changed, reset suffix
    if (dateStr != _currentDateStr) {
      _currentDateStr = dateStr;
      _currentFileSuffix = 1;
    }

    // Find the right file (check size)
    while (true) {
      final suffix = _currentFileSuffix == 1 ? '' : '_$_currentFileSuffix';
      final fileName = '$_logFilePrefix$dateStr$suffix.txt';
      final file = File(p.join(_logDir!.path, fileName));

      if (await file.exists()) {
        final stat = await file.stat();
        if (stat.size >= _maxFileSizeBytes) {
          _currentFileSuffix++;
          continue;
        }
      }

      _currentLogFile = file;
      break;
    }
  }

  Future<void> _cleanOldLogs() async {
    if (_logDir == null) return;

    try {
      final files = await _logDir!.list().toList();
      final logFiles = files
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(_logFilePrefix))
          .toList();

      if (logFiles.length <= _maxLogFiles) return;

      // Sort by modification time, oldest first
      logFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      // Delete oldest files
      final toDelete = logFiles.length - _maxLogFiles;
      for (var i = 0; i < toDelete; i++) {
        try {
          await logFiles[i].delete();
          debugPrint('Deleted old log: ${logFiles[i].path}');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Failed to clean old logs: $e');
    }
  }

  void _enqueueWrite(String content) {
    _writeQueue.add(content);
    _processWriteQueue();
  }

  Future<void> _processWriteQueue() async {
    if (_isWriting) return;
    if (_writeQueue.isEmpty) return;
    if (_currentLogFile == null) return;

    _isWriting = true;
    _writeCompleter = Completer<void>();

    try {
      final buffer = StringBuffer();
      while (_writeQueue.isNotEmpty) {
        buffer.write(_writeQueue.removeFirst());
      }

      // Check if we need to rotate
      if (await _currentLogFile!.exists()) {
        final stat = await _currentLogFile!.stat();
        if (stat.size >= _maxFileSizeBytes) {
          _currentFileSuffix++;
          await _openTodayLogFile();
        }
      }

      await _currentLogFile!.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('Log write failed: $e');
    } finally {
      _isWriting = false;
      _writeCompleter?.complete();
      _writeCompleter = null;

      // Process any queued items
      if (_writeQueue.isNotEmpty) {
        _processWriteQueue();
      }
    }
  }

  /// Wait for pending writes to complete
  Future<void> flush() async {
    while (_writeQueue.isNotEmpty || _isWriting) {
      await _writeCompleter?.future;
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
}

/// Global logger instance shortcut
GhostLogger get glog => GhostLogger.instance;
