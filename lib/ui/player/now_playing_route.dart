import 'package:flutter/material.dart';

import 'package:ghostmusic/ui/player/player_panel.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

abstract final class NowPlayingRoute {
  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      isDismissible: true,
      enableDrag: true,
      constraints: const BoxConstraints(),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.none,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return SizedBox(
          height: size.height,
          child: const PlayerPanel(),
        );
      },
    );
  }
}
