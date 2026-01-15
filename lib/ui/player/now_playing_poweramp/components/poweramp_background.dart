import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Poweramp-style dark immersive background derived from artwork.
///
/// Features:
/// - Heavily blurred artwork base
/// - Strong bottom darkening gradient
/// - Subtle depth without neon
/// - Cached palette extraction
class PowerampBackground extends StatefulWidget {
  final String? artworkPath;

  const PowerampBackground({
    super.key,
    required this.artworkPath,
  });

  @override
  State<PowerampBackground> createState() => _PowerampBackgroundState();
}

class _PowerampBackgroundState extends State<PowerampBackground> {
  PaletteGenerator? _palette;
  bool _loading = false;
  String? _loadedPath;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(covariant PowerampBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkPath != widget.artworkPath) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final path = widget.artworkPath;
    if (path == null || path == _loadedPath || _loading) return;

    _loading = true;

    try {
      final file = File(path);
      if (!await file.exists()) {
        _loading = false;
        return;
      }

      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(file),
        size: const Size(80, 80), // Small size for performance
        maximumColorCount: 6,
      );

      if (mounted && widget.artworkPath == path) {
        setState(() {
          _palette = palette;
          _loadedPath = path;
          _loading = false;
        });
      }
    } catch (_) {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    // Extract colors from palette
    Color dominant = const Color(0xFF1A1E26);
    Color muted = const Color(0xFF141820);
    Color dark = const Color(0xFF0C0E12);

    if (palette != null) {
      dominant = palette.dominantColor?.color ?? dominant;
      muted = palette.mutedColor?.color ?? palette.darkMutedColor?.color ?? muted;
      dark = palette.darkMutedColor?.color ?? palette.darkVibrantColor?.color ?? dark;

      // Significantly darken for Poweramp's dark aesthetic
      dominant = _darken(dominant, 0.18);
      muted = _darken(muted, 0.12);
      dark = _darken(dark, 0.06);
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base black
          const ColoredBox(color: Color(0xFF0A0C10)),

          // Blurred artwork (if available)
          if (widget.artworkPath != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Image.file(
                    File(widget.artworkPath!),
                    key: ValueKey(widget.artworkPath),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // Dark gradient overlay (Poweramp style - strong bottom darkening)
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  dominant.withValues(alpha: 0.75),
                  muted.withValues(alpha: 0.85),
                  dark.withValues(alpha: 0.92),
                  const Color(0xFF0A0C10).withValues(alpha: 0.98),
                ],
                stops: const [0.0, 0.30, 0.60, 1.0],
              ),
            ),
          ),

          // Subtle vignette
          const _Vignette(),

          // Very subtle noise texture
          const _NoiseTexture(opacity: 0.025),
        ],
      ),
    );
  }

  Color _darken(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.02, 0.12))
        .withSaturation((hsl.saturation * 0.6).clamp(0.05, 0.35))
        .toColor();
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.25),
            radius: 1.4,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.20),
              Colors.black.withValues(alpha: 0.45),
            ],
            stops: const [0.0, 0.60, 1.0],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NoiseTexture extends StatelessWidget {
  final double opacity;

  const _NoiseTexture({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _NoisePainter(opacity: opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final double opacity;

  _NoisePainter({required this.opacity});

  // Pre-generated noise points (static for performance)
  static final List<Offset> _points = _generateNoisePoints(1000);

  static List<Offset> _generateNoisePoints(int count) {
    final rnd = Random(42);
    return List.generate(count, (_) => Offset(rnd.nextDouble(), rnd.nextDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final scaledPoints = _points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList(growable: false);

    canvas.drawPoints(PointMode.points, scaledPoints, paint);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}

// Simple random for noise generation
class Random {
  int _seed;
  Random(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}
