import 'package:flutter/material.dart';

import 'package:ghostmusic/ui/player/player_panel.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

abstract final class NowPlayingRoute {
  static Future<void> open(BuildContext context) {
    // Full-screen modal sheet. 
    // - useSafeArea: false => PlayerPanel handles SafeArea internally
    // - enableDrag: false => PlayerPanel handles its own header-drag-to-dismiss
    // - isScrollControlled: true => allows full height
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      isDismissible: true,
      enableDrag: false, // PlayerPanel header handles dismiss
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (ctx) {
        // Use full screen height; PlayerPanel manages its own layout
        final size = MediaQuery.sizeOf(context);
        return SizedBox(
          height: size.height,
          width: size.width,
          child: const PlayerPanel(),
        );
      },
    );
  }
}