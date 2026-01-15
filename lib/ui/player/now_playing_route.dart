import 'package:flutter/material.dart';

import 'package:ghostmusic/ui/player/now_playing_poweramp/now_playing_poweramp_screen.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

abstract final class NowPlayingRoute {
  static Future<void> open(BuildContext context) {
    // Full-screen modal sheet with Poweramp-style Now Playing.
    // - useSafeArea: false => Screen handles SafeArea internally
    // - enableDrag: false => Screen handles its own drag-to-dismiss
    // - isScrollControlled: true => allows full height
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      isDismissible: true,
      enableDrag: false, // NowPlayingPowerampScreen handles dismiss
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (ctx) {
        // Use full screen height
        final size = MediaQuery.sizeOf(context);
        return SizedBox(
          height: size.height,
          width: size.width,
          child: const NowPlayingPowerampScreen(),
        );
      },
    );
  }
}