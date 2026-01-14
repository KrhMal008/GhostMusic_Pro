import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../services/cover_art_service.dart';
import '../services/ghost_audio_handler.dart';
import 'playback_state.dart';

/// Resolves an artwork image path for a track, if available.
///
/// For now we use a simple heuristic: look for common cover filenames in the
/// same folder as the audio file. If nothing is found, returns null.
final trackArtworkPathProvider = FutureProvider.autoDispose.family<String?, String>((ref, trackPath) async {
  // 0) User override (by artist+album)
  final override = await CoverArtService.getOverrideForFile(trackPath);
  if (override != null) return override;

  // 1) Embedded artwork cached by MetadataService (art_${hash}.jpg/png)
  try {
    final tmp = await getApplicationSupportDirectory();
    final base = p.join(tmp.path, 'artwork_cache');
    final hash = trackPath.hashCode;

    final jpg = File(p.join(base, 'art_$hash.jpg'));
    if (await jpg.exists()) return jpg.path;

    final png = File(p.join(base, 'art_$hash.png'));
    if (await png.exists()) return png.path;
  } catch (_) {
    // ignore, fall back.
  }

  // 2) Folder-level artwork fallback (cover.jpg etc)
  final directoryPath = _safeDirname(trackPath);
  if (directoryPath != null) {
    final dir = Directory(directoryPath);
    if (await dir.exists()) {
      const candidates = <String>[
        'cover.jpg',
        'cover.png',
        'folder.jpg',
        'folder.png',
        'front.jpg',
        'front.png',
        'artwork.jpg',
        'artwork.png',
      ];

      for (final name in candidates) {
        final path = '${dir.path}${Platform.pathSeparator}$name';
        final file = File(path);
        if (await file.exists()) return file.path;
      }
    }
  }

  // 3) Online lookup is intentionally not automatic.
  // Use CoverPickerSheet to fetch/select covers on demand.
  return null;
});

/// Same as [trackArtworkPathProvider], but kept for compatibility with older
/// callsites.
final trackArtworkPathProviderCompat = trackArtworkPathProvider;

final playbackControllerProvider = StateNotifierProvider<PlaybackController, PlaybackState>((ref) {
  return PlaybackController();
});

class PlaybackController extends StateNotifier<PlaybackState> {
  PlaybackController() : super(const PlaybackState.initial()) {
    _deckA = _PlaybackDeck(
      onPlaying: _onDeckPlaying,
      onPosition: _onDeckPosition,
      onDuration: _onDeckDuration,
      onCompleted: _onDeckCompleted,
    );
    _deckB = _PlaybackDeck(
      onPlaying: _onDeckPlaying,
      onPosition: _onDeckPosition,
      onDuration: _onDeckDuration,
      onCompleted: _onDeckCompleted,
    );
    _activeDeck = _deckA;

    _initAudio();
    _initAudioHandler();
    unawaited(_loadAutomixPrefs());

    // Start with empty queue; user selects tracks from library.
  }
  
  // --- iOS Now Playing / Remote Controls ---
  
  void _initAudioHandler() {
    final handler = GhostAudioHandler.instance;
    if (handler == null) return;
    
    // Bind remote command callbacks
    handler.onPlay = () => togglePlayPause();
    handler.onPause = () => togglePlayPause();
    handler.onSkipToNext = () => next();
    handler.onSkipToPrevious = () => previous();
    handler.onSeek = (position) => seek(position);
    handler.onStop = () {
      _enqueue(() async {
        await _activeDeck.pause();
        await _activeDeck.seek(Duration.zero);
        state = state.copyWith(isPlaying: false, position: Duration.zero);
      });
    };
  }
  
  /// Update Now Playing info for iOS Control Center / Lock Screen.
  Future<void> _updateNowPlaying() async {
    final handler = GhostAudioHandler.instance;
    if (handler == null) return;
    
    final track = state.currentTrack;
    if (track == null) {
      handler.updateStopped();
      return;
    }
    
    // Try to get artwork URI
    Uri? artUri;
    try {
      final artworkPath = await _resolveArtworkPath(track.filePath);
      if (artworkPath != null) {
        artUri = Uri.file(artworkPath);
      }
    } catch (_) {
      // Artwork lookup failed, continue without it
    }
    
    handler.updateNowPlaying(
      title: track.displayTitle,
      artist: track.artist,
      album: track.album,
      duration: state.duration,
      artUri: artUri,
      trackId: track.filePath,
    );
  }
  
  /// Resolve artwork path for Now Playing (simpler version of trackArtworkPathProvider).
  Future<String?> _resolveArtworkPath(String trackPath) async {
    // Check user override
    final override = await CoverArtService.getOverrideForFile(trackPath);
    if (override != null) return override;
    
    // Check embedded artwork cache
    try {
      final tmp = await getApplicationSupportDirectory();
      final base = p.join(tmp.path, 'artwork_cache');
      final hash = trackPath.hashCode;
      
      final jpg = File(p.join(base, 'art_$hash.jpg'));
      if (await jpg.exists()) return jpg.path;
      
      final png = File(p.join(base, 'art_$hash.png'));
      if (await png.exists()) return png.path;
    } catch (_) {}
    
    // Check folder artwork
    final dirPath = p.dirname(trackPath);
    const candidates = ['cover.jpg', 'cover.png', 'folder.jpg', 'folder.png'];
    for (final name in candidates) {
      final file = File(p.join(dirPath, name));
      if (await file.exists()) return file.path;
    }
    
    return null;
  }
  
  /// Update iOS playback state (position, playing status).
  void _updatePlaybackStateForHandler() {
    final handler = GhostAudioHandler.instance;
    if (handler == null) return;
    
    handler.updatePlaybackState(
      playing: state.isPlaying,
      position: state.position,
      bufferedPosition: state.position,
      speed: 1.0,
    );
  }

  // --- Preferences ---

  static const _prefsAutomixEnabled = 'automix_enabled';
  static const _prefsAutomixProfile = 'automix_profile';
  static const _prefsAutomixBeatmatch = 'automix_beatmatch';
  static const _prefsAutomixEq = 'automix_eq';
  static const _prefsAutomixMaxTempoDelta = 'automix_max_tempo_delta';

  // Kept for backward compatibility (older builds used explicit seconds).
  static const _prefsAutomixCrossfadeMs = 'automix_crossfade_ms';
  static const _prefsAutomixPreRollMs = 'automix_preroll_ms';

  // --- Decks ---

  late final _PlaybackDeck _deckA;
  late final _PlaybackDeck _deckB;
  late _PlaybackDeck _activeDeck;

  _PlaybackDeck get _inactiveDeck => identical(_activeDeck, _deckA) ? _deckB : _deckA;

  // --- Playback ---

  bool _handlingCompletion = false;

  Future<void> _opChain = Future.value();
  int _setQueueToken = 0;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _opChain = _opChain.then((_) async {
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });

    return completer.future;
  }

  // --- Automix ---

  final _AutomixTailAnalyzer _tailAnalyzer = _AutomixTailAnalyzer();

  Timer? _mixTimer;
  DateTime? _mixStartedAt;
  Duration _mixElapsed = Duration.zero;

  _AutomixPlan? _plannedPlan;
  String? _plannedPlanKey;

  _AutomixPlan? _preparedPlan;
  _AutomixPlan? _activeMixPlan;

  int _planToken = 0;
  String? _planInFlightKey;
  Future<void>? _planInFlight;

  Timer? _rateReturnTimer;

  double _lastEqOutHz = -1;
  double _lastEqInHz = -1;

  Future<void> _loadAutomixPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final enabled = prefs.getBool(_prefsAutomixEnabled);
      final profileRaw = prefs.getString(_prefsAutomixProfile);
      final beatmatch = prefs.getBool(_prefsAutomixBeatmatch);
      final eq = prefs.getBool(_prefsAutomixEq);
      final maxTempoDelta = prefs.getDouble(_prefsAutomixMaxTempoDelta);

      // Legacy values (ignored by UI; may act as hint if user had older version).
      final legacyPreRollMs = prefs.getInt(_prefsAutomixPreRollMs);
      final legacyCrossfadeMs = prefs.getInt(_prefsAutomixCrossfadeMs);

      state = state.copyWith(
        automixEnabled: enabled ?? state.automixEnabled,
        automixProfile: _parseAutomixProfile(profileRaw) ?? state.automixProfile,
        automixBeatmatch: beatmatch ?? state.automixBeatmatch,
        automixEq: eq ?? state.automixEq,
        automixMaxTempoDelta: _clampTempoDelta(maxTempoDelta ?? state.automixMaxTempoDelta),
        automixPreRoll: legacyPreRollMs == null
            ? state.automixPreRoll
            : _clampPreRoll(Duration(milliseconds: legacyPreRollMs)),
        // Keep in state for UI; if legacy was present, show it until we plan a real transition.
        automixCrossfade: legacyCrossfadeMs == null
            ? state.automixCrossfade
            : _clampLegacyCrossfade(Duration(milliseconds: legacyCrossfadeMs)),
      );
    } catch (e) {
      debugPrint('Automix prefs load failed: $e');
    }
  }

  AutomixProfile? _parseAutomixProfile(String? raw) {
    final v = raw?.trim().toLowerCase();
    return switch (v) {
      'club' => AutomixProfile.club,
      'smooth' => AutomixProfile.smooth,
      _ => null,
    };
  }

  String _automixProfileToString(AutomixProfile profile) {
    return switch (profile) {
      AutomixProfile.smooth => 'smooth',
      AutomixProfile.club => 'club',
    };
  }

  Duration _clampLegacyCrossfade(Duration value) {
    final ms = value.inMilliseconds.clamp(2000, 20000);
    return Duration(milliseconds: ms);
  }

  Duration _clampPreRoll(Duration value) {
    final ms = value.inMilliseconds.clamp(4000, 16000);
    return Duration(milliseconds: ms);
  }

  double _clampTempoDelta(double value) {
    final clamped = value.clamp(0.0, 0.12);
    // Avoid NaN propagation.
    if (clamped.isNaN || !clamped.isFinite) return 0.06;
    return clamped;
  }

  Future<void> setAutomixEnabled(bool enabled) {
    return _enqueue(() async {
      state = state.copyWith(automixEnabled: enabled);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsAutomixEnabled, enabled);
      } catch (_) {}

      if (!enabled && state.mixPhase != MixPhase.off) {
        await _abortAutomix();
      }

      if (!enabled) {
        _plannedPlan = null;
        _plannedPlanKey = null;
      }
    });
  }

  Future<void> setAutomixBeatmatchEnabled(bool enabled) {
    return _enqueue(() async {
      state = state.copyWith(automixBeatmatch: enabled);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsAutomixBeatmatch, enabled);
      } catch (_) {}

      if (state.mixPhase != MixPhase.off) {
        await _abortAutomix();
      }

      _plannedPlan = null;
      _plannedPlanKey = null;
    });
  }

  Future<void> setAutomixEqEnabled(bool enabled) {
    return _enqueue(() async {
      state = state.copyWith(automixEq: enabled);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsAutomixEq, enabled);
      } catch (_) {}

      if (state.mixPhase != MixPhase.off) {
        await _abortAutomix();
      }

      _plannedPlan = null;
      _plannedPlanKey = null;
    });
  }

  Future<void> setAutomixProfile(AutomixProfile profile) {
    return _enqueue(() async {
      state = state.copyWith(automixProfile: profile);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsAutomixProfile, _automixProfileToString(profile));
      } catch (_) {}

      if (state.mixPhase != MixPhase.off) {
        await _abortAutomix();
      }

      _plannedPlan = null;
      _plannedPlanKey = null;
    });
  }

  // --- Deck bindings ---

  DateTime? _lastHandlerUpdate;

  void _onDeckPlaying(_PlaybackDeck deck, bool playing) {
    final activePlaying = _activeDeck.lastPlaying;
    final mixingPlaying = (state.mixPhase == MixPhase.mixing) && _inactiveDeck.lastPlaying;
    final overall = activePlaying || mixingPlaying;

    if (state.isPlaying != overall) {
      state = state.copyWith(isPlaying: overall);
      // Update iOS Now Playing state
      _updatePlaybackStateForHandler();
    }
  }

  void _onDeckPosition(_PlaybackDeck deck, Duration position) {
    if (!identical(deck, _activeDeck)) return;

    state = state.copyWith(position: position);
    _maybeScheduleAutomix();
    
    // Throttle iOS handler updates to ~1Hz to avoid excessive updates
    final now = DateTime.now();
    if (_lastHandlerUpdate == null || 
        now.difference(_lastHandlerUpdate!) >= const Duration(milliseconds: 1000)) {
      _lastHandlerUpdate = now;
      _updatePlaybackStateForHandler();
    }
  }

  void _onDeckDuration(_PlaybackDeck deck, Duration? duration) {
    if (!identical(deck, _activeDeck)) return;
    state = state.copyWith(currentDuration: duration);
    // Update Now Playing when duration becomes known
    if (duration != null) {
      unawaited(_updateNowPlaying());
    }
  }

  void _onDeckCompleted(_PlaybackDeck deck) {
    if (!identical(deck, _activeDeck)) return;
    if (state.mixPhase != MixPhase.off) return;
    unawaited(_enqueue(() => _handleCompleted()));
  }

  // --- Playback helpers ---

  String? _playbackUnsupportedReason(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.cue') {
      return 'CUE-файл не является аудио: нужен импорт/разбиение на треки';
    }

    if (Platform.isWindows && filePath.length > 240) {
      return null;
    }

    try {
      if (!File(filePath).existsSync()) {
        return 'Файл не найден: $filePath';
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  bool _shouldUseMediaKitForPath(String filePath) {
    if (Platform.isWindows) return true;
    return false;
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('AudioSession init failed: $e');
    }
  }

  Future<void> _activateSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {
      // ignore
    }
  }

  // --- Automix planner ---

  void _maybeScheduleAutomix() {
    if (!state.automixEnabled) return;
    if (!state.isPlaying) return;
    if (state.mixPhase == MixPhase.mixing) return;

    final currentIndex = state.currentIndex;
    final duration = state.duration;
    if (currentIndex == null || duration == null) return;
    if (state.queue.length < 2) return;

    if (state.repeatMode == 1) {
      if (state.mixPhase != MixPhase.off) {
        unawaited(_enqueue(_abortAutomix));
      }
      return;
    }

    final nextIndex = _nextIndex(currentIndex, state.queue.length);
    final shouldStop = (nextIndex == currentIndex) && state.repeatMode != 2;
    if (shouldStop) return;

    final remaining = duration - state.position;

    // Start planning & tail-analysis only once we are inside the last ~minute.
    // This avoids doing heavy work early and matches the DJ expectation.
    if (remaining > const Duration(seconds: 75)) {
      return;
    }

    _requestAutomixPlan(currentIndex: currentIndex, nextIndex: nextIndex, duration: duration);

    final plan = _plannedPlan;
    if (plan == null || plan.fromIndex != currentIndex || plan.toIndex != nextIndex) {
      return;
    }

    final untilMix = plan.mixStart - state.position;
    final preloadWindow = _preloadWindowForPlan(plan);

    if (untilMix <= Duration.zero) {
      if (state.mixPhase == MixPhase.preparing && _preparedPlan?.key == plan.key) {
        unawaited(_enqueue(_startMixIfReady));
      } else if (state.mixPhase == MixPhase.off) {
        unawaited(
          _enqueue(() async {
            await _prepareAutomix(plan);
            await _startMixIfReady();
          }),
        );
      }
      return;
    }

    if (untilMix <= preloadWindow) {
      if (state.mixPhase == MixPhase.off) {
        unawaited(_enqueue(() => _prepareAutomix(plan)));
      } else if (state.mixPhase == MixPhase.preparing) {
        if (_preparedPlan?.key != plan.key) {
          unawaited(_enqueue(() => _prepareAutomix(plan)));
        }
      }
      return;
    }

    if (state.mixPhase == MixPhase.preparing) {
      unawaited(_enqueue(_abortAutomix));
    }
  }

  Duration _preloadWindowForPlan(_AutomixPlan plan) {
    final base = state.automixPreRoll;

    // Heuristic: longer mixes need more pre-roll to avoid late decoding hiccups.
    final extra = plan.mixDuration ~/ 3;
    final desired = base + extra;

    final ms = desired.inMilliseconds.clamp(4000, 16000);
    return Duration(milliseconds: ms);
  }

  void _requestAutomixPlan({
    required int currentIndex,
    required int nextIndex,
    required Duration duration,
  }) {
    final from = state.queue[currentIndex];
    final to = state.queue[nextIndex];

    final key = '${from.uniqueKey}|${to.uniqueKey}|${duration.inMilliseconds}|${state.automixProfile}|'
        '${state.automixBeatmatch}|${state.automixEq}|${state.automixMaxTempoDelta}';

    if (_plannedPlanKey == key) return;

    final inFlightKey = _planInFlightKey;
    final inFlight = _planInFlight;

    if (inFlightKey == key && inFlight != null) return;

    final token = ++_planToken;

    _planInFlightKey = key;

    // Fire & forget: planning must never block playback controls.
    final future = _computeAutomixPlan(
      fromIndex: currentIndex,
      toIndex: nextIndex,
      duration: duration,
      token: token,
      key: key,
    ).whenComplete(() {
      if (_planInFlightKey == key) {
        _planInFlight = null;
      }
    });

    _planInFlight = future;
    unawaited(future);
  }

  Future<void> _computeAutomixPlan({
    required int fromIndex,
    required int toIndex,
    required Duration duration,
    required int token,
    required String key,
  }) async {
    final from = state.queue[fromIndex];
    final to = state.queue[toIndex];

    Duration? analyzedExit;
    try {
      analyzedExit = await _tailAnalyzer
          .findExitPoint(from, duration)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      analyzedExit = null;
    }

    if (token != _planToken) return;

    // Track changed while we were analyzing.
    if (state.currentIndex != fromIndex) return;

    final plan = _buildAutomixPlan(
      fromIndex: fromIndex,
      toIndex: toIndex,
      from: from,
      to: to,
      duration: duration,
      exitTime: analyzedExit,
    );

    if (token != _planToken) return;

    _plannedPlan = plan;
    _plannedPlanKey = key;

    // Expose planned mix duration to UI (purely informational).
    if (state.automixCrossfade != plan.mixDuration && state.mixPhase == MixPhase.off) {
      state = state.copyWith(automixCrossfade: plan.mixDuration);
    }
  }

  _AutomixPlan _buildAutomixPlan({
    required int fromIndex,
    required int toIndex,
    required Track from,
    required Track to,
    required Duration duration,
    required Duration? exitTime,
  }) {
    final rawExit = _pickExitTime(exitTime: exitTime, duration: duration);

    final bpmFrom = from.bpm;
    final bpmTo = to.bpm;
    final bpmRef = bpmFrom ?? bpmTo;

    // Keep the transition musically aligned (bar grid) when BPM is known.
    final exit = (bpmRef == null || bpmRef <= 0) ? rawExit : _alignDownToBar(rawExit, bpmRef);

    final mixDuration = _autoMixDuration(
      profile: state.automixProfile,
      bpmRef: bpmRef,
      duration: duration,
      exit: exit,
    );

    final mixStart = (exit - mixDuration).isNegative ? Duration.zero : (exit - mixDuration);

    final incomingRate = _computeBeatmatchRate(
      bpmFrom: bpmFrom,
      bpmTo: bpmTo,
      enabled: state.automixBeatmatch,
      maxTempoDelta: state.automixMaxTempoDelta,
    );

    final bassCutHz = _bassCutHzForProfile(state.automixProfile);

    return _AutomixPlan(
      fromIndex: fromIndex,
      toIndex: toIndex,
      mixStart: mixStart,
      mixDuration: mixDuration,
      exitTime: exit,
      incomingCue: Duration.zero,
      incomingRate: incomingRate,
      bassCutHz: bassCutHz,
      profile: state.automixProfile,
      key: '$fromIndex->$toIndex@${mixStart.inMilliseconds}+${mixDuration.inMilliseconds}',
    );
  }

  Duration _pickExitTime({required Duration? exitTime, required Duration duration}) {
    if (exitTime == null) return duration;

    // We only consider analysis in the last minute.
    final lowerBound = duration - const Duration(minutes: 1);
    if (exitTime < lowerBound) return duration;

    // Too close to the end: doesn't help.
    if (duration - exitTime < const Duration(seconds: 3)) return duration;

    return exitTime;
  }

  Duration _alignDownToBar(Duration position, double bpm, {int bars = 1}) {
    if (bpm <= 0) return position;

    final beatMs = (60000.0 / bpm).round();
    final barMs = beatMs * 4 * bars;
    if (barMs <= 0) return position;

    final ms = (position.inMilliseconds ~/ barMs) * barMs;
    return Duration(milliseconds: ms.clamp(0, position.inMilliseconds));
  }

  Duration _autoMixDuration({
    required AutomixProfile profile,
    required double? bpmRef,
    required Duration duration,
    required Duration exit,
  }) {
    // Default values when BPM is unknown.
    final defaultSeconds = profile == AutomixProfile.club ? 8 : 12;

    if (bpmRef == null || bpmRef <= 0) {
      final ms = (defaultSeconds * 1000).clamp(6000, 18000);
      return Duration(milliseconds: ms);
    }

    final beatMs = (60000.0 / bpmRef).round();
    final barMs = beatMs * 4;

    // Target number of bars depends on style and track length.
    var targetBars = switch (profile) {
      AutomixProfile.club => 4,
      AutomixProfile.smooth => 8,
    };

    if (duration >= const Duration(minutes: 7)) {
      targetBars += 4;
    } else if (duration <= const Duration(minutes: 2)) {
      targetBars = math.max(2, targetBars - 2);
    }

    final minMs = 6000.0;
    final maxMs = 18000.0;

    final minBars = math.max(1, (minMs / barMs).ceil());
    final maxBars = math.max(1, (maxMs / barMs).floor());

    targetBars = targetBars.clamp(minBars, maxBars);

    // Keep it musically aligned: even number of bars.
    if (targetBars > 1 && targetBars.isOdd) {
      targetBars = math.min(maxBars, targetBars + 1);
      if (targetBars.isOdd) targetBars = math.max(minBars, targetBars - 1);
    }

    var ms = targetBars * barMs;

    // Never exceed the available outro window.
    final maxAllowed = exit.inMilliseconds.clamp(0, 1 << 30);
    if (ms > maxAllowed) {
      ms = maxAllowed;
    }

    // Guard.
    ms = ms.clamp(2000, 20000);
    return Duration(milliseconds: ms);
  }

  double _computeBeatmatchRate({
    required double? bpmFrom,
    required double? bpmTo,
    required bool enabled,
    required double maxTempoDelta,
  }) {
    if (!enabled) return 1.0;
    if (bpmFrom == null || bpmTo == null) return 1.0;
    if (bpmFrom <= 0 || bpmTo <= 0) return 1.0;

    final candidates = <double>[bpmTo / 2.0, bpmTo, bpmTo * 2.0];

    double bestRate = 1.0;
    double bestError = double.infinity;

    for (final candidate in candidates) {
      if (candidate <= 0) continue;
      final rate = bpmFrom / candidate;
      final err = (rate - 1.0).abs();
      if (err < bestError) {
        bestError = err;
        bestRate = rate;
      }
    }

    final minRate = 1.0 - maxTempoDelta;
    final maxRate = 1.0 + maxTempoDelta;

    if (bestRate < minRate || bestRate > maxRate) {
      return 1.0;
    }

    return bestRate.clamp(0.5, 2.0);
  }

  double _bassCutHzForProfile(AutomixProfile profile) {
    return switch (profile) {
      AutomixProfile.smooth => 160,
      AutomixProfile.club => 220,
    };
  }

  Future<void> _prepareAutomix(_AutomixPlan plan) async {
    if (!state.automixEnabled) return;
    if (state.mixPhase == MixPhase.mixing) return;

    // Avoid cross-contamination if user is rapidly skipping.
    _cancelRateReturn();

    _preparedPlan = plan;
    _activeMixPlan = null;

    state = state.copyWith(mixPhase: MixPhase.preparing, mixProgress01: 0.0, automixCrossfade: plan.mixDuration);

    final nextTrack = state.queue[plan.toIndex];
    final preferMediaKit = _shouldUseMediaKitForPath(nextTrack.filePath);

    try {
      // Prepare incoming deck.
      await _inactiveDeck.pause();
      await _inactiveDeck.seek(Duration.zero);
      await _inactiveDeck.setVolume(1.0);
      await _inactiveDeck.setRate(1.0);
      await _inactiveDeck.setHighPassHz(null);

      await _inactiveDeck.loadTrack(
        nextTrack,
        autoplay: false,
        preferMediaKit: preferMediaKit,
        activateSession: _activateSession,
      );

      // Beatmatch + cue.
      await _inactiveDeck.setRate(plan.incomingRate);
      await _inactiveDeck.seek(plan.incomingCue);

      // DJ-EQ: start with incoming bass cut.
      if (state.automixEq) {
        await _inactiveDeck.setHighPassHz(plan.bassCutHz);
        await _activeDeck.setHighPassHz(null);
      }

      await _inactiveDeck.setVolume(0.0);
    } catch (e) {
      _preparedPlan = null;
      state = state.copyWith(mixPhase: MixPhase.off, mixProgress01: 0.0);
      debugPrint('Automix prepare failed: $e');
    }
  }

  Future<void> _startMixIfReady() async {
    if (!state.automixEnabled) {
      await _abortAutomix();
      return;
    }

    if (!state.isPlaying) return;
    if (state.mixPhase == MixPhase.mixing) return;

    final plan = _preparedPlan;
    if (plan == null) return;

    if (state.currentIndex != plan.fromIndex) return;
    if (state.position < plan.mixStart) return;

    final outgoing = _activeDeck;
    final incoming = _inactiveDeck;

    _activeMixPlan = plan;

    state = state.copyWith(mixPhase: MixPhase.mixing, mixProgress01: 0.0);

    _stopMixTimer();
    _mixElapsed = Duration.zero;

    _lastEqOutHz = -1;
    _lastEqInHz = -1;

    try {
      await outgoing.setVolume(1.0);
    } catch (_) {}

    try {
      await incoming.setVolume(0.0);
      await incoming.setRate(plan.incomingRate);
      await incoming.seek(plan.incomingCue);

      if (state.automixEq) {
        await outgoing.setHighPassHz(null);
        await incoming.setHighPassHz(plan.bassCutHz);
      }
    } catch (_) {}

    await _activateSession();
    await incoming.play();

    _mixStartedAt = DateTime.now();
    _mixTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tickMix());
  }

  void _tickMix() {
    if (state.mixPhase != MixPhase.mixing) {
      _stopMixTimer();
      return;
    }

    final plan = _activeMixPlan;
    final startedAt = _mixStartedAt;

    if (plan == null || startedAt == null) {
      _stopMixTimer();
      unawaited(_enqueue(_completeMix));
      return;
    }

    final durationMs = plan.mixDuration.inMilliseconds;
    if (durationMs <= 0) {
      _stopMixTimer();
      unawaited(_enqueue(_completeMix));
      return;
    }

    final elapsed = _mixElapsed + DateTime.now().difference(startedAt);
    final t = (elapsed.inMilliseconds / durationMs).clamp(0.0, 1.0);

    // Equal-power crossfade.
    final toVol = math.sin(t * math.pi / 2);
    final fromVol = math.cos(t * math.pi / 2);

    unawaited(_activeDeck.setVolume(fromVol));
    unawaited(_inactiveDeck.setVolume(toVol));

    _applyDjEqIfNeeded(plan: plan, t: t);

    if ((t - state.mixProgress01).abs() >= 0.01 || t == 1.0) {
      state = state.copyWith(mixProgress01: t);
    }

    if (t >= 1.0) {
      _stopMixTimer();
      _mixStartedAt = null;
      _mixElapsed = Duration.zero;
      unawaited(_enqueue(_completeMix));
    }
  }

  void _applyDjEqIfNeeded({required _AutomixPlan plan, required double t}) {
    if (!state.automixEq) return;

    // Only meaningful on MediaKit backend; just_audio falls back silently.
    final hz = plan.bassCutHz;
    if (hz <= 0) return;

    // Bass swap timing differs per profile.
    final (swapStart, swapEnd) = switch (plan.profile) {
      AutomixProfile.smooth => (0.35, 0.78),
      AutomixProfile.club => (0.50, 0.68),
    };

    final k = ((t - swapStart) / (swapEnd - swapStart)).clamp(0.0, 1.0);
    final eased = 0.5 - 0.5 * math.cos(math.pi * k);

    final outHz = hz * eased;
    final inHz = hz * (1.0 - eased);

    // Throttle EQ updates.
    if ((_lastEqOutHz - outHz).abs() > 6) {
      _lastEqOutHz = outHz;
      unawaited(_activeDeck.setHighPassHz(outHz <= 4 ? null : outHz));
    }

    if ((_lastEqInHz - inHz).abs() > 6) {
      _lastEqInHz = inHz;
      unawaited(_inactiveDeck.setHighPassHz(inHz <= 4 ? null : inHz));
    }
  }

  void _stopMixTimer() {
    _mixTimer?.cancel();
    _mixTimer = null;
  }

  void _cancelRateReturn() {
    _rateReturnTimer?.cancel();
    _rateReturnTimer = null;
  }

  void _scheduleRateReturn({required _PlaybackDeck deck, required double fromRate, required AutomixProfile profile}) {
    if ((fromRate - 1.0).abs() < 0.001) return;

    _cancelRateReturn();

    final duration = profile == AutomixProfile.club
        ? const Duration(seconds: 8)
        : const Duration(seconds: 12);

    final start = DateTime.now();

    _rateReturnTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final elapsed = DateTime.now().difference(start);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 0.5 - 0.5 * math.cos(math.pi * t);

      final rate = fromRate + (1.0 - fromRate) * eased;
      unawaited(deck.setRate(rate));

      if (t >= 1.0) {
        timer.cancel();
        _rateReturnTimer = null;
      }
    });
  }

  Future<void> _completeMix() async {
    if (state.mixPhase != MixPhase.mixing) return;

    final plan = _activeMixPlan;
    if (plan == null) {
      await _abortAutomix();
      return;
    }

    final toIndex = plan.toIndex;
    if (toIndex < 0 || toIndex >= state.queue.length) {
      await _abortAutomix();
      return;
    }

    final outgoing = _activeDeck;
    final incoming = _inactiveDeck;

    // Reset FX on outgoing first (avoid leaving filters behind).
    try {
      await outgoing.setHighPassHz(null);
      await outgoing.setRate(1.0);
    } catch (_) {}

    try {
      await outgoing.setVolume(0.0);
    } catch (_) {}

    try {
      await outgoing.pause();
    } catch (_) {}

    try {
      await outgoing.seek(Duration.zero);
    } catch (_) {}

    try {
      await outgoing.setVolume(1.0);
    } catch (_) {}

    // Incoming becomes active.
    try {
      await incoming.setVolume(1.0);
      await incoming.setHighPassHz(null);
    } catch (_) {}

    _activeDeck = incoming;

    state = state.copyWith(
      currentIndex: toIndex,
      position: incoming.lastPosition,
      currentDuration: incoming.lastDuration,
      mixPhase: MixPhase.off,
      mixProgress01: 0.0,
      isPlaying: incoming.lastPlaying,
      lastError: null,
    );

    // Bring tempo back to normal after the transition.
    if (state.automixBeatmatch) {
      _scheduleRateReturn(deck: _activeDeck, fromRate: plan.incomingRate, profile: plan.profile);
    } else {
      try {
        await _activeDeck.setRate(1.0);
      } catch (_) {}
    }

    _preparedPlan = null;
    _activeMixPlan = null;

    _mixElapsed = Duration.zero;
    _mixStartedAt = null;
  }

  Future<void> _abortAutomix() async {
    _planToken++;

    _planInFlightKey = null;
    _planInFlight = null;

    _stopMixTimer();
    _cancelRateReturn();

    _mixStartedAt = null;
    _mixElapsed = Duration.zero;

    _preparedPlan = null;
    _activeMixPlan = null;

    _lastEqOutHz = -1;
    _lastEqInHz = -1;

    try {
      await _activeDeck.setVolume(1.0);
      await _activeDeck.setHighPassHz(null);
      await _activeDeck.setRate(1.0);
    } catch (_) {}

    try {
      await _inactiveDeck.setHighPassHz(null);
      await _inactiveDeck.setRate(1.0);
      await _inactiveDeck.setVolume(1.0);
      await _inactiveDeck.pause();
      await _inactiveDeck.seek(Duration.zero);
    } catch (_) {}

    if (state.mixPhase != MixPhase.off || state.mixProgress01 != 0.0) {
      state = state.copyWith(mixPhase: MixPhase.off, mixProgress01: 0.0);
    }
  }

  // --- End of track ---

  Future<void> _handleCompleted() async {
    if (_handlingCompletion) return;
    _handlingCompletion = true;

    try {
      final currentIndex = state.currentIndex;
      if (currentIndex == null || state.queue.isEmpty) return;

      if (state.repeatMode == 1) {
        await _loadWithFallback(currentIndex, autoplay: true, allowWrap: false);
        return;
      }

      final nextIndex = _nextIndex(currentIndex, state.queue.length);
      final shouldStop = (nextIndex == currentIndex) && state.repeatMode != 2;

      if (shouldStop) {
        try {
          await _activeDeck.pause();
          await _activeDeck.seek(Duration.zero);
        } catch (_) {}

        state = state.copyWith(isPlaying: false, position: Duration.zero);
        return;
      }

      await _loadWithFallback(nextIndex, autoplay: true, allowWrap: state.repeatMode == 2);
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> _loadIndex(int index, {required bool autoplay}) async {
    if (index < 0 || index >= state.queue.length) return;

    final track = state.queue[index];
    final reason = _playbackUnsupportedReason(track.filePath);
    if (reason != null) {
      throw Exception(reason);
    }

    await _abortAutomix();

    _plannedPlan = null;
    _plannedPlanKey = null;

    state = state.copyWith(
      currentIndex: index,
      isPlaying: false,
      position: Duration.zero,
      currentDuration: null,
      lastError: null,
      mixPhase: MixPhase.off,
      mixProgress01: 0.0,
    );

    final preferMediaKit = _shouldUseMediaKitForPath(track.filePath);
    await _activeDeck.loadTrack(
      track,
      autoplay: autoplay,
      preferMediaKit: preferMediaKit,
      activateSession: _activateSession,
    );

    if (autoplay) {
      state = state.copyWith(isPlaying: _activeDeck.lastPlaying);
    }
    
    // Update iOS Now Playing with new track info
    unawaited(_updateNowPlaying());
    _updatePlaybackStateForHandler();
  }

  Future<void> _loadWithFallback(
    int startIndex, {
    required bool autoplay,
    bool allowWrap = true,
  }) async {
    final length = state.queue.length;
    if (length == 0) return;

    var index = startIndex.clamp(0, length - 1);

    for (var attempt = 0; attempt < length; attempt++) {
      try {
        await _loadIndex(index, autoplay: autoplay);
        state = state.copyWith(lastError: null);
        return;
      } catch (e) {
        state = state.copyWith(lastError: e.toString(), isPlaying: false);

        if (!allowWrap && index == length - 1) {
          break;
        }

        index = (index + 1) % length;
      }
    }

    throw Exception(state.lastError ?? 'Не удалось воспроизвести трек');
  }

  // --- Public API ---

  Future<void> setQueue(List<Track> queue, {int startIndex = 0, bool autoplay = false}) {
    final token = ++_setQueueToken;

    return _enqueue(() async {
      await _abortAutomix();

      _plannedPlan = null;
      _plannedPlanKey = null;

      final safeIndex = queue.isEmpty ? null : startIndex.clamp(0, queue.length - 1);

      if (queue.isEmpty || safeIndex == null) {
        state = state.copyWith(
          queue: const [],
          currentIndex: null,
          isPlaying: false,
          position: Duration.zero,
          currentDuration: null,
          lastError: null,
          mixPhase: MixPhase.off,
          mixProgress01: 0.0,
        );

        try {
          await _activeDeck.pause();
        } catch (_) {}

        try {
          await _inactiveDeck.pause();
        } catch (_) {}
        
        // Update iOS handler with stopped state
        GhostAudioHandler.instance?.updateStopped();

        return;
      }

      final playable = <Track>[];
      int? initialIndex;

      for (var i = 0; i < queue.length; i++) {
        final track = queue[i];
        final reason = _playbackUnsupportedReason(track.filePath);
        if (reason != null) {
          debugPrint('Skipping unplayable track: ${track.filePath} ($reason)');
          continue;
        }

        if (i == safeIndex) {
          initialIndex = playable.length;
        }

        playable.add(track);
      }

      if (playable.isEmpty || initialIndex == null) {
        throw Exception('Нет воспроизводимых треков в очереди');
      }

      state = state.copyWith(
        queue: playable,
        currentIndex: initialIndex,
        isPlaying: false,
        position: Duration.zero,
        currentDuration: null,
        lastError: null,
        mixPhase: MixPhase.off,
        mixProgress01: 0.0,
      );

      if (token != _setQueueToken) return;

      await _loadWithFallback(initialIndex, autoplay: autoplay);
    });
  }

  /// Adds a track to the end of the current queue.
  ///
  /// If there is no active playlist yet, this will create a new queue.
  Future<void> addToQueueEnd(Track track, {bool autoplayIfEmpty = false}) {
    return _enqueue(() async {
      final reason = _playbackUnsupportedReason(track.filePath);
      if (reason != null) {
        debugPrint('addToQueueEnd skipped: $reason');
        return;
      }

      if (state.queue.isEmpty) {
        // Don't await to avoid deadlock inside _enqueue.
        setQueue([track], startIndex: 0, autoplay: autoplayIfEmpty);
        return;
      }

      final updatedQueue = [...state.queue, track];
      state = state.copyWith(queue: updatedQueue);
    });
  }

  /// Inserts a track right after the current one (Poweramp-like "Play Next").
  Future<void> playNext(Track track) async {
    final reason = _playbackUnsupportedReason(track.filePath);
    if (reason != null) {
      debugPrint('playNext skipped: $reason');
      return;
    }

    if (state.queue.isEmpty) {
      await setQueue([track], startIndex: 0, autoplay: true);
      return;
    }

    final current = state.currentIndex ?? 0;
    final insertIndex = (current + 1).clamp(0, state.queue.length);

    try {
      final updated = [...state.queue];
      updated.insert(insertIndex, track);

      // Keep currently playing item as-is.
      state = state.copyWith(queue: updated);
    } catch (e) {
      debugPrint('playNext failed: $e');
    }
  }

  /// Removes an item from the queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.queue.length) return;

    return _enqueue(() async {
      await _abortAutomix();

      _plannedPlan = null;
      _plannedPlanKey = null;

      final wasPlaying = state.isPlaying;
      final current = state.currentIndex;

      final updated = [...state.queue]..removeAt(index);

      int? nextIndex = current;
      if (nextIndex != null) {
        if (updated.isEmpty) {
          nextIndex = null;
        } else if (index < nextIndex) {
          nextIndex = nextIndex - 1;
        } else if (index == nextIndex) {
          nextIndex = nextIndex.clamp(0, updated.length - 1);
        }
      }

      state = state.copyWith(queue: updated, currentIndex: nextIndex);

      if (updated.isEmpty || nextIndex == null) {
        try {
          await _activeDeck.pause();
        } catch (_) {}
        state = state.copyWith(position: Duration.zero, currentDuration: null, isPlaying: false);
        return;
      }

      // If we removed the currently playing item, load the new current.
      if (current == index) {
        await _loadWithFallback(nextIndex, autoplay: wasPlaying);
      }
    });
  }

  Future<void> togglePlayPause() {
    return _enqueue(() async {
      if (!state.hasTrack) return;

      final isActuallyPlaying = _activeDeck.isActuallyPlaying ||
          (state.mixPhase == MixPhase.mixing && _inactiveDeck.isActuallyPlaying);

      try {
        if (isActuallyPlaying) {
          if (state.mixPhase == MixPhase.mixing) {
            _pauseMixTimer();
            await _activeDeck.pause();
            await _inactiveDeck.pause();
          } else {
            await _activeDeck.pause();
          }
        } else {
          await _activateSession();

          if (state.mixPhase == MixPhase.mixing) {
            await _activeDeck.play();
            await _inactiveDeck.play();
            _resumeMixTimer();
          } else {
            await _activeDeck.play();
          }
        }
      } catch (e) {
        debugPrint('togglePlayPause failed: $e');
        state = state.copyWith(isPlaying: !state.isPlaying, lastError: e.toString());
      }
    });
  }

  void _pauseMixTimer() {
    final startedAt = _mixStartedAt;
    if (startedAt == null) return;

    _mixElapsed += DateTime.now().difference(startedAt);
    _mixStartedAt = null;
    _stopMixTimer();
  }

  void _resumeMixTimer() {
    if (state.mixPhase != MixPhase.mixing) return;
    if (_mixTimer != null) return;

    _mixStartedAt = DateTime.now();
    _mixTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tickMix());
  }

  Future<void> next() {
    return _enqueue(() async {
      if (state.queue.isEmpty) return;

      await _abortAutomix();

      _plannedPlan = null;
      _plannedPlanKey = null;

      final current = state.currentIndex ?? 0;
      final nextIndex = _nextIndex(current, state.queue.length);
      if (nextIndex == current && state.repeatMode != 2) return;

      await _loadWithFallback(nextIndex, autoplay: true, allowWrap: state.repeatMode == 2);
    });
  }

  Future<void> previous() {
    return _enqueue(() async {
      if (state.queue.isEmpty) return;

      await _abortAutomix();

      _plannedPlan = null;
      _plannedPlanKey = null;

      // Poweramp-like behavior: if position > ~3s, restart current track.
      if (state.position.inSeconds >= 3) {
        try {
          await _activeDeck.seek(Duration.zero);
        } catch (_) {}

        state = state.copyWith(position: Duration.zero);
        return;
      }

      final current = state.currentIndex ?? 0;
      final previousIndex = _previousIndex(current, state.queue.length);
      if (previousIndex == current && state.repeatMode != 2) return;

      await _loadWithFallback(previousIndex, autoplay: true, allowWrap: state.repeatMode == 2);
    });
  }

  Future<void> seek(Duration position) {
    return _enqueue(() async {
      await _abortAutomix();

      _plannedPlan = null;
      _plannedPlanKey = null;

      try {
        await _activeDeck.seek(position);
      } catch (e) {
        debugPrint('seek failed: $e');
      }

      final d = state.duration;
      if (d == null) return;

      final clampedMs = position.inMilliseconds.clamp(0, d.inMilliseconds);
      state = state.copyWith(position: Duration(milliseconds: clampedMs));
    });
  }

  Future<void> seekToIndex(int index) {
    return _enqueue(() async {
      if (state.queue.isEmpty) return;
      if (index < 0 || index >= state.queue.length) return;

      await _abortAutomix();

      _plannedPlan = null;
      _plannedPlanKey = null;

      await _loadWithFallback(index, autoplay: true);
    });
  }

  Future<void> toggleShuffle() {
    return _enqueue(() async {
      final next = !state.shuffleEnabled;
      state = state.copyWith(shuffleEnabled: next);
    });
  }

  Future<void> toggleRepeat() {
    return _enqueue(() async {
      await _abortAutomix();

      final next = switch (state.repeatMode) {
        0 => 2,
        2 => 1,
        _ => 0,
      };

      state = state.copyWith(repeatMode: next);

      try {
        await _activeDeck.setRepeatOne(next == 1);
      } catch (e) {
        debugPrint('setLoopMode failed: $e');
      }
    });
  }

  int _nextIndex(int current, int length) {
    if (length <= 0) return 0;

    if (state.shuffleEnabled) {
      // Simple shuffle: pick next index deterministically-ish.
      // (Real shuffle history will come later.)
      return (current + 1) % length;
    }

    final candidate = current + 1;
    if (candidate < length) return candidate;

    if (state.repeatMode == 2) return 0;
    return current;
  }

  int _previousIndex(int current, int length) {
    if (length <= 0) return 0;

    if (state.shuffleEnabled) {
      return (current - 1 + length) % length;
    }

    final candidate = current - 1;
    if (candidate >= 0) return candidate;

    if (state.repeatMode == 2) return length - 1;
    return current;
  }

  @override
  void dispose() {
    _stopMixTimer();
    _cancelRateReturn();

    _deckA.dispose();
    _deckB.dispose();

    super.dispose();
  }
}

class _AutomixPlan {
  final int fromIndex;
  final int toIndex;

  final Duration mixStart;
  final Duration mixDuration;
  final Duration exitTime;

  final Duration incomingCue;
  final double incomingRate;

  final double bassCutHz;
  final AutomixProfile profile;

  final String key;

  const _AutomixPlan({
    required this.fromIndex,
    required this.toIndex,
    required this.mixStart,
    required this.mixDuration,
    required this.exitTime,
    required this.incomingCue,
    required this.incomingRate,
    required this.bassCutHz,
    required this.profile,
    required this.key,
  });
}

class _AutomixTailAnalyzer {
  final Map<String, _TailAnalysis?> _cache = <String, _TailAnalysis?>{};
  final Map<String, Future<_TailAnalysis?>> _inFlight = <String, Future<_TailAnalysis?>>{};

  Future<Duration?> findExitPoint(Track track, Duration duration) async {
    // MediaKit log-based analysis is currently only used on Windows.
    if (!Platform.isWindows) return null;

    final key = track.uniqueKey;

    final cached = _cache[key];
    if (cached != null) return cached.exitTime;

    final existing = _inFlight[key];
    if (existing != null) {
      final a = await existing;
      return a?.exitTime;
    }

    final future = _scanTail(track, duration).whenComplete(() {
      _inFlight.remove(key);
    });

    _inFlight[key] = future;

    final analysis = await future;
    _cache[key] = analysis;

    return analysis?.exitTime;
  }

  Future<_TailAnalysis?> _scanTail(Track track, Duration duration) async {
    try {
      // Guard: if duration is not valid, don't analyze.
      if (duration.inMilliseconds <= 0) return null;

      final filePath = track.filePath;
      if (!File(filePath).existsSync()) return null;

      mk.MediaKit.ensureInitialized();

      final player = mk.Player(
        configuration: const mk.PlayerConfiguration(
          vo: 'null',
          osc: false,
          pitch: false,
          muted: true,
          title: 'Ghost Music Automix Analyzer',
          logLevel: mk.MPVLogLevel.info,
          bufferSize: 8 * 1024 * 1024,
        ),
      );

      final silenceStartRe = RegExp(r'silence_start:\s*([0-9.]+)');
      final silenceEndRe = RegExp(r'silence_end:\s*([0-9.]+)\s*\|\s*silence_duration:\s*([0-9.]+)');

      final segments = <_SilenceSegment>[];
      Duration? currentStart;

      late final StreamSubscription<mk.PlayerLog> logSub;

      void flushOpenSegment({required Duration end}) {
        final s = currentStart;
        currentStart = null;
        if (s == null) return;
        if (end <= s) return;
        segments.add(_SilenceSegment(start: s, end: end));
      }

      logSub = player.stream.log.listen((log) {
        final text = log.text;

        final startMatch = silenceStartRe.firstMatch(text);
        if (startMatch != null) {
          final v = double.tryParse(startMatch.group(1) ?? '');
          if (v != null && v.isFinite && v >= 0) {
            currentStart = Duration(milliseconds: (v * 1000).round());
          }
          return;
        }

        final endMatch = silenceEndRe.firstMatch(text);
        if (endMatch != null) {
          final endSeconds = double.tryParse(endMatch.group(1) ?? '');
          if (endSeconds != null && endSeconds.isFinite && endSeconds >= 0) {
            final end = Duration(milliseconds: (endSeconds * 1000).round());
            flushOpenSegment(end: end);
          }
        }
      });

      try {
        // Disable audio output entirely (best effort).
        try {
          final dynamic platform = player.platform;
          await platform.setProperty('ao', 'null');
        } catch (_) {
          // ignore
        }

        // Enable silence detection filter.
        try {
          final dynamic platform = player.platform;
          await platform.setProperty('af', 'lavfi=[silencedetect=n=-36dB:d=0.45]');
        } catch (_) {
          // ignore
        }

        await player.open(
          mk.Media(
            Uri.file(track.filePath).toString(),
            start: track.start,
            end: track.end,
          ),
          play: false,
        );

        final tailStart = (duration - const Duration(minutes: 1)).isNegative
            ? Duration.zero
            : (duration - const Duration(minutes: 1));

        // Scan quickly.
        const scanRate = 6.0;

        try {
          await player.setRate(scanRate);
        } catch (_) {}

        try {
          await player.seek(tailStart);
        } catch (_) {}

        await player.play();

        // Scan duration depends on how much tail exists.
        final tailLen = duration - tailStart;
        final scanMs = (tailLen.inMilliseconds / scanRate).ceil();
        final scanDuration = Duration(milliseconds: (scanMs + 250).clamp(250, 12000));

        await Future<void>.delayed(scanDuration);

        try {
          await player.pause();
        } catch (_) {}

        // Close segment if it runs until the end.
        flushOpenSegment(end: duration);

        // Pick best exit point.
        final threshold = const Duration(milliseconds: 900);
        final lowerBound = duration - const Duration(minutes: 1);

        final candidates = segments
            .where((s) => s.duration >= threshold)
            .where((s) => s.start >= lowerBound)
            .where((s) => duration - s.start >= const Duration(seconds: 3))
            .toList(growable: false);

        if (candidates.isEmpty) {
          return const _TailAnalysis(exitTime: null);
        }

        // Prefer the latest silence start near the end.
        candidates.sort((a, b) => b.start.compareTo(a.start));

        return _TailAnalysis(exitTime: candidates.first.start);
      } finally {
        await logSub.cancel();
        await player.dispose();
      }
    } catch (e) {
      debugPrint('Tail analysis failed: $e');
      return null;
    }
  }
}

class _TailAnalysis {
  final Duration? exitTime;

  const _TailAnalysis({required this.exitTime});
}

class _SilenceSegment {
  final Duration start;
  final Duration end;

  const _SilenceSegment({required this.start, required this.end});

  Duration get duration => end - start;
}

class _PlaybackDeck {
  final AudioPlayer _player = AudioPlayer();

  mk.Player? _mkPlayer;

  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  bool _useMediaKit = false;

  double _volume01 = 1.0;
  double _lastSentVolume01 = -1;

  double _rate = 1.0;
  double _lastSentRate = -1;

  double? _highPassHz;
  double _lastSentHighPassHz = -1;

  Duration lastPosition = Duration.zero;
  Duration? lastDuration;
  bool lastPlaying = false;

  bool get isActuallyPlaying {
    if (_useMediaKit) return _mkPlayer?.state.playing ?? false;
    return _player.playing;
  }

  final void Function(_PlaybackDeck deck, bool playing) onPlaying;
  final void Function(_PlaybackDeck deck, Duration position) onPosition;
  final void Function(_PlaybackDeck deck, Duration? duration) onDuration;
  final void Function(_PlaybackDeck deck) onCompleted;

  _PlaybackDeck({
    required this.onPlaying,
    required this.onPosition,
    required this.onDuration,
    required this.onCompleted,
  }) {
    _subscriptions.add(
      _player.playerStateStream.listen((playerState) {
        if (_useMediaKit) return;

        lastPlaying = playerState.playing;
        onPlaying(this, playerState.playing);

        if (playerState.processingState == ProcessingState.completed) {
          onCompleted(this);
        }
      }),
    );

    _subscriptions.add(
      _player.positionStream.listen((position) {
        if (_useMediaKit) return;
        lastPosition = position;
        onPosition(this, position);
      }),
    );

    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (_useMediaKit) return;
        lastDuration = duration;
        onDuration(this, duration);
      }),
    );
  }

  Future<void> _ensureMediaKit() async {
    if (_mkPlayer != null) return;

    mk.MediaKit.ensureInitialized();

    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        osc: false,
        pitch: false,
        title: 'Ghost Music',
        logLevel: mk.MPVLogLevel.error,
      ),
    );

    try {
      final dynamic platform = player.platform;
      await platform.setProperty('cache', 'yes');
      await platform.setProperty('cache-on-disk', 'no');
    } catch (_) {
      // ignore
    }

    _mkPlayer = player;

    _subscriptions.add(
      player.stream.playing.listen((playing) {
        if (!_useMediaKit) return;
        lastPlaying = playing;
        onPlaying(this, playing);
      }),
    );

    _subscriptions.add(
      player.stream.position.listen((position) {
        if (!_useMediaKit) return;
        lastPosition = position;
        onPosition(this, position);
      }),
    );

    _subscriptions.add(
      player.stream.duration.listen((duration) {
        if (!_useMediaKit) return;
        lastDuration = duration;
        onDuration(this, duration);
      }),
    );

    _subscriptions.add(
      player.stream.completed.listen((completed) {
        if (!_useMediaKit) return;
        if (!completed) return;
        onCompleted(this);
      }),
    );
  }

  AudioSource _sourceForTrack(Track track) {
    final uri = Uri.file(track.filePath);
    final base = AudioSource.uri(uri, tag: track);

    final start = track.start;
    final end = track.end;
    if (start != null || end != null) {
      return ClippingAudioSource(child: base, start: start, end: end);
    }

    return base;
  }

  mk.Media _mediaForTrack(Track track) {
    return mk.Media(
      Uri.file(track.filePath).toString(),
      start: track.start,
      end: track.end,
    );
  }

  Future<void> loadTrack(
    Track track, {
    required bool autoplay,
    required bool preferMediaKit,
    required Future<void> Function() activateSession,
  }) async {
    if (preferMediaKit) {
      _useMediaKit = true;

      try {
        await _player.pause();
      } catch (_) {}

      await _ensureMediaKit();

      final player = _mkPlayer;
      if (player == null) throw Exception('MediaKit init failed');

      try {
        if (autoplay) {
          await activateSession();
        }
        await player.open(_mediaForTrack(track), play: autoplay);
        await setVolume(_volume01);
        await setRate(_rate);
        await setHighPassHz(_highPassHz);
        return;
      } catch (_) {
        _useMediaKit = false;
      }
    }

    _useMediaKit = false;

    try {
      await _mkPlayer?.pause();
    } catch (_) {}

    try {
      await _player.pause();
    } catch (_) {}

    try {
      await _player.setAudioSource(
        _sourceForTrack(track),
        initialPosition: Duration.zero,
      );

      if (autoplay) {
        await activateSession();
        await _player.play();
      }

      await setVolume(_volume01);
      await setRate(_rate);
      return;
    } catch (_) {
      _useMediaKit = true;
      await _ensureMediaKit();

      final mkp = _mkPlayer;
      if (mkp == null) rethrow;

      if (autoplay) {
        await activateSession();
      }

      await mkp.open(_mediaForTrack(track), play: autoplay);
      await setVolume(_volume01);
      await setRate(_rate);
      await setHighPassHz(_highPassHz);
    }
  }

  Future<void> play() async {
    if (_useMediaKit) {
      await _mkPlayer?.play();
    } else {
      await _player.play();
    }
  }

  Future<void> pause() async {
    if (_useMediaKit) {
      await _mkPlayer?.pause();
    } else {
      await _player.pause();
    }
  }

  Future<void> seek(Duration position) async {
    if (_useMediaKit) {
      await _mkPlayer?.seek(position);
    } else {
      await _player.seek(position);
    }
  }

  Future<void> setRepeatOne(bool enabled) async {
    if (_useMediaKit) {
      await _mkPlayer?.setPlaylistMode(enabled ? mk.PlaylistMode.single : mk.PlaylistMode.none);
    } else {
      await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    }
  }

  Future<void> setVolume(double volume01) async {
    final clamped = volume01.clamp(0.0, 1.0);
    _volume01 = clamped;

    if ((_lastSentVolume01 - clamped).abs() < 0.01) return;
    _lastSentVolume01 = clamped;

    if (_useMediaKit) {
      await _mkPlayer?.setVolume(clamped * 100.0);
    } else {
      await _player.setVolume(clamped);
    }
  }

  Future<void> setRate(double rate) async {
    final clamped = rate.clamp(0.5, 2.0);
    _rate = clamped;

    if ((_lastSentRate - clamped).abs() < 0.001) return;
    _lastSentRate = clamped;

    if (_useMediaKit) {
      await _mkPlayer?.setRate(clamped);
    } else {
      await _player.setSpeed(clamped);
    }
  }

  Future<void> setHighPassHz(double? hz) async {
    final clamped = hz?.clamp(0.0, 500.0);
    _highPassHz = clamped;

    final sent = clamped ?? 0.0;
    if ((_lastSentHighPassHz - sent).abs() < 1.0) return;
    _lastSentHighPassHz = sent;

    if (!_useMediaKit) return;

    final player = _mkPlayer;
    if (player == null) return;

    try {
      final dynamic platform = player.platform;

      if (clamped == null || clamped <= 4) {
        await platform.setProperty('af', '');
      } else {
        final f = clamped.round();
        await platform.setProperty('af', 'lavfi=[highpass=f=$f]');
      }
    } catch (_) {
      // ignore
    }
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    _mkPlayer?.dispose();
    _player.dispose();
  }
}

String? _safeDirname(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  if (parts.length <= 1) return null;
  parts.removeLast();
  return parts.join(Platform.pathSeparator);
}
