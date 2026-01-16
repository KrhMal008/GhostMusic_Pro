import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// AirPlay route picker button that shows the iOS system audio route picker.
///
/// On iOS: Uses native AVRoutePickerView via platform channel
/// On other platforms: Shows disabled icon or opens a custom sheet
class AirPlayRoutePickerButton extends StatelessWidget {
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const AirPlayRoutePickerButton({
    super.key,
    this.size = 32,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Only show native picker on iOS
    if (Platform.isIOS) {
      return _IOSAirPlayButton(
        size: size,
        iconColor: iconColor,
        backgroundColor: backgroundColor,
      );
    }

    // Fallback for other platforms - show cast icon with tap handler
    return _FallbackAirPlayButton(
      size: size,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
    );
  }
}

/// iOS native AirPlay route picker using UiKitView
class _IOSAirPlayButton extends StatefulWidget {
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const _IOSAirPlayButton({
    required this.size,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  State<_IOSAirPlayButton> createState() => _IOSAirPlayButtonState();
}

class _IOSAirPlayButtonState extends State<_IOSAirPlayButton> {
  static const _channel = MethodChannel('com.ghostmusic/airplay');

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? Colors.black.withValues(alpha: 0.45);
    final fgColor = widget.iconColor ?? Colors.white.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: _showRoutePicker,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.size / 2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
        child: Icon(
          Icons.airplay_rounded,
          size: widget.size * 0.55,
          color: fgColor,
        ),
      ),
    );
  }

  Future<void> _showRoutePicker() async {
    HapticFeedback.selectionClick();
    try {
      await _channel.invokeMethod('showRoutePicker');
    } on PlatformException catch (e) {
      debugPrint('AirPlay route picker error: ${e.message}');
    }
  }
}

/// Fallback for non-iOS platforms
class _FallbackAirPlayButton extends StatefulWidget {
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  const _FallbackAirPlayButton({
    required this.size,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  State<_FallbackAirPlayButton> createState() => _FallbackAirPlayButtonState();
}

class _FallbackAirPlayButtonState extends State<_FallbackAirPlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? Colors.black.withValues(alpha: 0.45);
    final fgColor = widget.iconColor ?? Colors.white.withValues(alpha: 0.85);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        _showFallbackSheet(context);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(widget.size / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.cast_rounded,
            size: widget.size * 0.55,
            color: fgColor,
          ),
        ),
      ),
    );
  }

  void _showFallbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cast_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Audio Output',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AirPlay is only available on iOS.\nUse system settings to change audio output.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
