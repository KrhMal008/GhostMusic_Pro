import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Poweramp-style background with color diffusion from artwork.
///
/// NOT too dark - maintains visible color haze everywhere.
/// Features:
/// - Multi-stop gradient (2-4 colors) from artwork
/// - Large blur/softness
/// - Subtle noise texture
/// - Strong bottom vignette but keeps color visible
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

  // Extracted colors with defaults
  Color _dominant = const Color(0xFF2A3040);
  Color _vibrant = const Color(0xFF3A4560);
  Color _muted = const Color(0xFF1E2535);
  Color _darkMuted = const Color(0xFF151A25);

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
        size: const Size(100, 100),
        maximumColorCount: 8,
      );

      if (mounted && widget.artworkPath == path) {
        setState(() {
          _palette = palette;
          _loadedPath = path;
          _loading = false;
          _extractColors();
        });
      }
    } catch (_) {
      _loading = false;
    }
  }

  void _extractColors() {
    final palette = _palette;
    if (palette == null) return;

    // Extract colors, keeping them visible (NOT too dark)
    _dominant = palette.dominantColor?.color ?? _dominant;
    _vibrant = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? _vibrant;
    _muted = palette.mutedColor?.color ?? palette.lightMutedColor?.color ?? _muted;
    _darkMuted = palette.darkMutedColor?.color ?? palette.darkVibrantColor?.color ?? _darkMuted;

    // Process colors: darken but keep visible
    _dominant = _processColor(_dominant, 0.35, 0.70);
    _vibrant = _processColor(_vibrant, 0.30, 0.75);
    _muted = _processColor(_muted, 0.25, 0.65);
    _darkMuted = _processColor(_darkMuted, 0.18, 0.55);
  }

  /// Process color: set lightness and saturation while keeping color identity
  Color _processColor(Color color, double lightness, double saturation) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(lightness.clamp(0.12, 0.40))
        .withSaturation((hsl.saturation * saturation).clamp(0.20, 0.65))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base layer with artwork-derived gradient (NOT BLACK)
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _dominant,
                  _vibrant,
                  _muted,
                  _darkMuted,
                ],
                stops: const [0.0, 0.30, 0.60, 1.0],
              ),
            ),
          ),

          // Blurred artwork overlay for texture
          if (widget.artworkPath != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Opacity(
                    opacity: 0.45, // Keep visible!
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
            ),

          // Radial color diffusion overlay (adds depth)
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.5),
                radius: 1.5,
                colors: [
                  _vibrant.withValues(alpha: 0.40),
                  _dominant.withValues(alpha: 0.30),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.40, 1.0],
              ),
            ),
          ),

          // Bottom vignette (strong but not killing colors)
          const _BottomVignette(),

          // Subtle noise texture
          const _NoiseTexture(opacity: 0.025),
        ],
      ),
    );
  }
}

class _BottomVignette extends StatelessWidget {
  const _BottomVignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.30),
              Colors.black.withValues(alpha: 0.60),
            ],
            stops: const [0.0, 0.50, 0.80, 1.0],
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

  static final List<Offset> _points = _generateNoisePoints(1200);

  static List<Offset> _generateNoisePoints(int count) {
    final rnd = _SimpleRandom(42);
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

class _SimpleRandom {
  int _seed;
  _SimpleRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }
}
