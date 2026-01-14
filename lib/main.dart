import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ghostmusic/domain/services/ghost_audio_handler.dart';
import 'package:ghostmusic/domain/services/http_overrides.dart';
import 'package:ghostmusic/ui/app_shell.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

// Windows dev UX: render as an iPhone 16 Pro viewport by default.
const bool kUseIPhone16ProPreviewOnWindows = true;

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio_service for iOS Now Playing / Control Center / remote controls.
  // On Windows, this is a no-op; playback uses MediaKit directly.
  await GhostAudioHandler.init();

  // Windows dev environments often require a proxy and can miss root CAs.
  // Install safe overrides for debug builds.
  GhostHttpOverrides.installForWindowsDebug();

  // Restore optional proxy rule (Windows debug).
  try {
    final prefs = await SharedPreferences.getInstance();
    GhostHttpOverrides.setProxyFromUserInput(prefs.getString('proxy_rule'));
  } catch (_) {
    // ignore
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  runApp(const ProviderScope(child: GhostMusicApp()));
}

class GhostMusicApp extends StatelessWidget {
  const GhostMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ghost Music',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const NoGlowScrollBehavior(),
      themeMode: ThemeMode.dark,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
       builder: (context, child) {
         final mediaQuery = MediaQuery.of(context);

         final clampedScale = mediaQuery.textScaler.scale(1.0).clamp(0.8, 1.3);
         final baseData = mediaQuery.copyWith(textScaler: TextScaler.linear(clampedScale));

         final content = child ?? const SizedBox.shrink();

         // Windows dev UX: render as an iPhone 16 Pro viewport by default.
         // This keeps the layout (spacing/typography) honest for iOS while staying stable on desktop.
          if (defaultTargetPlatform == TargetPlatform.windows && kUseIPhone16ProPreviewOnWindows) {

           const deviceSize = Size(402, 874); // iPhone 16 Pro (logical points)
           const safePadding = EdgeInsets.only(top: 59, bottom: 34);

           final available = mediaQuery.size;
           final scale = math.min(
             1.0,
             math.min(
               available.width / deviceSize.width,
               available.height / deviceSize.height,
             ),
           );

           final simulated = baseData.copyWith(
             size: deviceSize,
             padding: safePadding,
             viewPadding: safePadding,
           );

           return _AppContainer(
             child: Center(
               child: Transform.scale(
                 scale: scale,
                 alignment: Alignment.topCenter,
                 child: SizedBox(
                   width: deviceSize.width,
                   height: deviceSize.height,
                   child: MediaQuery(
                     data: simulated,
                     child: content,
                   ),
                 ),
               ),
             ),
           );
         }

         return MediaQuery(
           data: baseData,
           child: _AppContainer(child: content),
         );
       },

      home: const AppShell(),
    );
  }
}

class _AppContainer extends StatelessWidget {
  final Widget? child;

  const _AppContainer({this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColorsDark.background,
            AppColorsDark.backgroundElevated,
            AppColorsDark.backgroundSecondary,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  final VoidCallback? onResumed;
  final VoidCallback? onPaused;
  final VoidCallback? onInactive;
  final VoidCallback? onDetached;
  final VoidCallback? onHidden;

  AppLifecycleObserver({
    this.onResumed,
    this.onPaused,
    this.onInactive,
    this.onDetached,
    this.onHidden,
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed?.call();
        break;
      case AppLifecycleState.paused:
        onPaused?.call();
        break;
      case AppLifecycleState.inactive:
        onInactive?.call();
        break;
      case AppLifecycleState.detached:
        onDetached?.call();
        break;
      case AppLifecycleState.hidden:
        onHidden?.call();
        break;
    }
  }

}

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get viewPadding => mediaQuery.viewPadding;
  EdgeInsets get viewInsets => mediaQuery.viewInsets;
  double get topPadding => viewPadding.top;
  double get bottomPadding => viewPadding.bottom;

  bool get isKeyboardVisible => viewInsets.bottom > 0;
  double get keyboardHeight => viewInsets.bottom;

  bool get isDarkMode => theme.brightness == Brightness.dark;
  bool get isLightMode => theme.brightness == Brightness.light;

  bool get isSmallScreen => screenWidth < 375;
  bool get isMediumScreen => screenWidth >= 375 && screenWidth < 414;
  bool get isLargeScreen => screenWidth >= 414;
  bool get isTablet => screenWidth >= 600;

  double get safeAreaTop => topPadding;
  double get safeAreaBottom => bottomPadding > 0 ? bottomPadding : AppSpacing.screenVertical;

  void hideKeyboard() => FocusScope.of(this).unfocus();

  void showSnackBar(String message, {Duration? duration, SnackBarAction? action}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
        action: action,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: bottomPadding + AppSpacing.section3,
          left: AppSpacing.screenHorizontal,
          right: AppSpacing.screenHorizontal,
        ),
      ),
    );
  }
}

extension DurationX on Duration {
  String get formatted {
    final total = inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  String get formattedCompact {
    final total = inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedLong {
    final total = inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }
}

extension StringX on String {
  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) => word.capitalized).join(' ');
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }
}

extension ListX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;

  T? elementAtOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  List<T> separatedBy(T separator) {
    if (length <= 1) return this;
    final result = <T>[];
    for (var i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) result.add(separator);
    }
    return result;
  }
}

extension NumX on num {
  Duration get ms => Duration(milliseconds: toInt());
  Duration get seconds => Duration(seconds: toInt());
  Duration get minutes => Duration(minutes: toInt());

  double get normalized => clamp(0.0, 1.0).toDouble();

  String get fileSize {
    if (this < 1024) return '${toInt()} B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

extension ColorX on Color {
  Color get highOpacity => withValues(alpha: AppOpacity.dense);
  Color get mediumOpacity => withValues(alpha: AppOpacity.half);
  Color get lowOpacity => withValues(alpha: AppOpacity.gentle);
  Color get subtleOpacity => withValues(alpha: AppOpacity.subtle);

  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  Color saturate([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withSaturation((hsl.saturation + amount).clamp(0.0, 1.0)).toColor();
  }

  Color desaturate([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    return hsl.withSaturation((hsl.saturation - amount).clamp(0.0, 1.0)).toColor();
  }

  bool get isDark => computeLuminance() < 0.5;
  bool get isLight => !isDark;
  Color get contrastingTextColor => isDark ? Colors.white : Colors.black;
}

extension EdgeInsetsX on EdgeInsets {
  EdgeInsets get horizontal => EdgeInsets.symmetric(horizontal: left);
  EdgeInsets get vertical => EdgeInsets.symmetric(vertical: top);

  EdgeInsets addTop(double value) => copyWith(top: top + value);
  EdgeInsets addBottom(double value) => copyWith(bottom: bottom + value);
  EdgeInsets addLeft(double value) => copyWith(left: left + value);
  EdgeInsets addRight(double value) => copyWith(right: right + value);

  EdgeInsets subtractTop(double value) => copyWith(top: (top - value).clamp(0, double.infinity));
  EdgeInsets subtractBottom(double value) =>
      copyWith(bottom: (bottom - value).clamp(0, double.infinity));
}

extension BorderRadiusX on BorderRadius {
  BorderRadius get topOnly => copyWith(bottomLeft: Radius.zero, bottomRight: Radius.zero);
  BorderRadius get bottomOnly => copyWith(topLeft: Radius.zero, topRight: Radius.zero);
  BorderRadius get leftOnly => copyWith(topRight: Radius.zero, bottomRight: Radius.zero);
  BorderRadius get rightOnly => copyWith(topLeft: Radius.zero, bottomLeft: Radius.zero);
}

extension WidgetX on Widget {
  Widget get expanded => Expanded(child: this);
  Widget get flexible => Flexible(child: this);
  Widget get centered => Center(child: this);

  Widget padded(EdgeInsetsGeometry padding) => Padding(padding: padding, child: this);
  Widget paddedAll(double value) => Padding(padding: EdgeInsets.all(value), child: this);
  Widget paddedHorizontal(double value) =>
      Padding(padding: EdgeInsets.symmetric(horizontal: value), child: this);
  Widget paddedVertical(double value) =>
      Padding(padding: EdgeInsets.symmetric(vertical: value), child: this);

  Widget clipped({BorderRadius? borderRadius}) =>
      ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: this);

  Widget sized({double? width, double? height}) =>
      SizedBox(width: width, height: height, child: this);

  Widget opacity(double value) => Opacity(opacity: value, child: this);
  Widget get sliver => SliverToBoxAdapter(child: this);
  Widget hero(String tag) => Hero(tag: tag, child: this);

  Widget onTap(VoidCallback? onTap, {bool enabled = true}) {
    if (!enabled || onTap == null) return this;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: this);
  }

  Widget semantics({
    String? label,
    String? hint,
    bool? button,
    bool? header,
    bool? image,
    bool? link,
    bool? excludeSemantics,
  }) =>
      Semantics(
        label: label,
        hint: hint,
        button: button,
        header: header,
        image: image,
        link: link,
        excludeSemantics: excludeSemantics ?? false,
        child: this,
      );
}

mixin SafeSetStateMixin<T extends StatefulWidget> on State<T> {
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }
}

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

class Throttler {
  final Duration delay;
  DateTime? _lastCall;

  Throttler({this.delay = const Duration(milliseconds: 300)});

  void call(VoidCallback action) {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!) >= delay) {
      _lastCall = now;
      action();
    }
  }
}

class HapticHelper {
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void heavy() => HapticFeedback.heavyImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void vibrate() => HapticFeedback.vibrate();
}

class GhostIcons {
  GhostIcons._();

  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData stop = Icons.stop_rounded;
  static const IconData next = Icons.skip_next_rounded;
  static const IconData previous = Icons.skip_previous_rounded;
  static const IconData fastForward = Icons.fast_forward_rounded;
  static const IconData fastRewind = Icons.fast_rewind_rounded;

  static const IconData shuffle = Icons.shuffle_rounded;
  static const IconData shuffleOn = Icons.shuffle_on_rounded;
  static const IconData repeat = Icons.repeat_rounded;
  static const IconData repeatOne = Icons.repeat_one_rounded;
  static const IconData repeatOn = Icons.repeat_on_rounded;

  static const IconData volumeOff = Icons.volume_off_rounded;
  static const IconData volumeMute = Icons.volume_mute_rounded;
  static const IconData volumeDown = Icons.volume_down_rounded;
  static const IconData volumeUp = Icons.volume_up_rounded;

  static const IconData library = Icons.library_music_rounded;
  static const IconData album = Icons.album_rounded;
  static const IconData artist = Icons.person_rounded;
  static const IconData playlist = Icons.queue_music_rounded;
  static const IconData folder = Icons.folder_rounded;
  static const IconData folderOpen = Icons.folder_open_rounded;
  static const IconData track = Icons.music_note_rounded;
  static const IconData genre = Icons.category_rounded;

  static const IconData search = Icons.search_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData tune = Icons.tune_rounded;
  static const IconData equalizer = Icons.equalizer_rounded;
  static const IconData graphicEq = Icons.graphic_eq_rounded;

  static const IconData queue = Icons.queue_music_rounded;
  static const IconData queueAdd = Icons.add_to_queue_rounded;
  static const IconData playlistAdd = Icons.playlist_add_rounded;
  static const IconData playlistPlay = Icons.playlist_play_rounded;
  static const IconData playlistCheck = Icons.playlist_add_check_rounded;

  static const IconData favorite = Icons.favorite_rounded;
  static const IconData favoriteBorder = Icons.favorite_border_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData starBorder = Icons.star_border_rounded;
  static const IconData starHalf = Icons.star_half_rounded;

  static const IconData add = Icons.add_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData moreVert = Icons.more_vert_rounded;

  static const IconData arrowBack = Icons.arrow_back_rounded;
  static const IconData arrowForward = Icons.arrow_forward_rounded;
  static const IconData arrowUp = Icons.keyboard_arrow_up_rounded;
  static const IconData arrowDown = Icons.keyboard_arrow_down_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData expandLess = Icons.expand_less_rounded;

  static const IconData sort = Icons.sort_rounded;
  static const IconData sortByAlpha = Icons.sort_by_alpha_rounded;
  static const IconData filterList = Icons.filter_list_rounded;
  static const IconData viewList = Icons.view_list_rounded;
  static const IconData viewGrid = Icons.grid_view_rounded;
  static const IconData viewModule = Icons.view_module_rounded;

  static const IconData share = Icons.share_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData upload = Icons.upload_rounded;
  static const IconData cloud = Icons.cloud_rounded;
  static const IconData cloudDownload = Icons.cloud_download_rounded;
  static const IconData cloudUpload = Icons.cloud_upload_rounded;
  static const IconData cloudOff = Icons.cloud_off_rounded;

  static const IconData info = Icons.info_rounded;
  static const IconData infoOutline = Icons.info_outline_rounded;
  static const IconData help = Icons.help_rounded;
  static const IconData helpOutline = Icons.help_outline_rounded;
  static const IconData warning = Icons.warning_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData errorOutline = Icons.error_outline_rounded;

  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData deleteOutline = Icons.delete_outline_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData cut = Icons.cut_rounded;
  static const IconData paste = Icons.paste_rounded;

  static const IconData timer = Icons.timer_rounded;
  static const IconData timerOff = Icons.timer_off_rounded;
  static const IconData alarm = Icons.alarm_rounded;
  static const IconData schedule = Icons.schedule_rounded;
  static const IconData history = Icons.history_rounded;

  static const IconData bluetooth = Icons.bluetooth_rounded;
  static const IconData bluetoothConnected = Icons.bluetooth_connected_rounded;
  static const IconData bluetoothDisabled = Icons.bluetooth_disabled_rounded;
  static const IconData headphones = Icons.headphones_rounded;
  static const IconData speaker = Icons.speaker_rounded;
  static const IconData speakerGroup = Icons.speaker_group_rounded;
  static const IconData cast = Icons.cast_rounded;
  static const IconData castConnected = Icons.cast_connected_rounded;
  static const IconData airplay = Icons.airplay_rounded;

  static const IconData lyrics = Icons.lyrics_rounded;
  static const IconData textFields = Icons.text_fields_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData imageSearch = Icons.image_search_rounded;
  static const IconData photoLibrary = Icons.photo_library_rounded;

  static const IconData refresh = Icons.refresh_rounded;
  static const IconData sync = Icons.sync_rounded;
  static const IconData syncDisabled = Icons.sync_disabled_rounded;
  static const IconData syncProblem = Icons.sync_problem_rounded;

  static const IconData darkMode = Icons.dark_mode_rounded;
  static const IconData lightMode = Icons.light_mode_rounded;
  static const IconData autoMode = Icons.brightness_auto_rounded;

  static const IconData lock = Icons.lock_rounded;
  static const IconData lockOpen = Icons.lock_open_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;

  static const IconData drag = Icons.drag_handle_rounded;
  static const IconData reorder = Icons.reorder_rounded;
  static const IconData swapVert = Icons.swap_vert_rounded;
  static const IconData swapHoriz = Icons.swap_horiz_rounded;

  static const IconData playCircle = Icons.play_circle_rounded;
  static const IconData playCircleOutline = Icons.play_circle_outline_rounded;
  static const IconData pauseCircle = Icons.pause_circle_rounded;
  static const IconData pauseCircleOutline = Icons.pause_circle_outline_rounded;

  static const IconData nowPlaying = Icons.play_circle_fill_rounded;
  static const IconData waveform = Icons.graphic_eq_rounded;
  static const IconData visualizer = Icons.auto_graph_rounded;
}