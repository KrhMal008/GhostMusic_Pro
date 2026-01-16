import 'package:flutter/material.dart';

import 'package:ghostmusic/ui/player/now_playing_poweramp/now_playing_poweramp_screen.dart';
import 'package:ghostmusic/ui/theme/app_theme.dart';

abstract final class NowPlayingRoute {
  /// Opens Now Playing screen with fast animation (150ms vs default 250ms)
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(_NowPlayingPageRoute());
  }
}

/// Custom page route with fast slide-up animation for instant feel
class _NowPlayingPageRoute extends PageRouteBuilder<void> {
  _NowPlayingPageRoute()
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
          transitionDuration: const Duration(milliseconds: 150), // Faster!
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const NowPlayingPowerampScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fast slide-up with decelerate curve for snappy feel
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ));

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );

  @override
  bool get maintainState => true;
}