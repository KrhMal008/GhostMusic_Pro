import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Poweramp-style artwork card with premium depth and overlays.
///
/// Features:
/// - Large rounded artwork with shadow
/// - Cast icon overlay (top-right)
/// - Like/Dislike thumbs (bottom-left)
/// - Menu dots (bottom-right)
/// - Swipe left/right for prev/next track
/// - Long press for context menu
class PowerampArtworkCard extends StatefulWidget {
  final String? artworkPath;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLongPress;
  final VoidCallback onMenuTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onDislikeTap;
  final VoidCallback? onCastTap;
  final bool isLiked;
  final bool isDisliked;

  const PowerampArtworkCard({
    super.key,
    required this.artworkPath,
    required this.onPrevious,
    required this.onNext,
    required this.onLongPress,
    required this.onMenuTap,
    this.onLikeTap,
    this.onDislikeTap,
    this.onCastTap,
    this.isLiked = false,
    this.isDisliked = false,
  });

  @override
  State<PowerampArtworkCard> createState() => _PowerampArtworkCardState();
}

class _PowerampArtworkCardState extends State<PowerampArtworkCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swipeController;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  static const double _swipeThreshold = 80.0;
  static const double _maxDragOffset = 120.0;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _swipeController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(-_maxDragOffset, _maxDragOffset);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.abs() > _swipeThreshold || velocity.abs() > 500) {
      HapticFeedback.mediumImpact();
      if (_dragOffset > 0 || velocity > 500) {
        widget.onPrevious();
      } else {
        widget.onNext();
      }
    }

    // Animate back to center
    final startOffset = _dragOffset;
    _swipeController.reset();
    _swipeController.addListener(() {
      setState(() {
        _dragOffset = startOffset * (1 - _swipeController.value);
      });
    });
    _swipeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = screenWidth - 48; // 24px margin on each side

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      child: Transform.translate(
        offset: Offset(_dragOffset * 0.4, 0),
        child: Transform.scale(
          scale: 1 - (_dragOffset.abs() / _maxDragOffset) * 0.05,
          child: Container(
            width: artworkSize,
            height: artworkSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Artwork image
                  Positioned.fill(
                    child: _ArtworkImage(path: widget.artworkPath),
                  ),

                  // Subtle border
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Cast icon (top-right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _OverlayButton(
                      icon: Icons.cast_rounded,
                      onTap: widget.onCastTap,
                      size: 32,
                    ),
                  ),

                  // Like/Dislike (bottom-left)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        _OverlayButton(
                          icon: Icons.thumb_up_outlined,
                          activeIcon: Icons.thumb_up_rounded,
                          isActive: widget.isLiked,
                          onTap: widget.onLikeTap,
                          size: 36,
                        ),
                        const SizedBox(width: 8),
                        _OverlayButton(
                          icon: Icons.thumb_down_outlined,
                          activeIcon: Icons.thumb_down_rounded,
                          isActive: widget.isDisliked,
                          onTap: widget.onDislikeTap,
                          size: 36,
                        ),
                      ],
                    ),
                  ),

                  // Menu dots (bottom-right)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: _OverlayButton(
                      icon: Icons.more_vert_rounded,
                      onTap: widget.onMenuTap,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  final String? path;

  const _ArtworkImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return _placeholder(context);
    }

    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2D35),
            const Color(0xFF1A1D25),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80,
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final bool isActive;
  final VoidCallback? onTap;
  final double size;

  const _OverlayButton({
    required this.icon,
    this.activeIcon,
    this.isActive = false,
    this.onTap,
    required this.size,
  });

  @override
  State<_OverlayButton> createState() => _OverlayButtonState();
}

class _OverlayButtonState extends State<_OverlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final displayIcon = widget.isActive && widget.activeIcon != null
        ? widget.activeIcon!
        : widget.icon;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(widget.size / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          child: Icon(
            displayIcon,
            size: widget.size * 0.5,
            color: widget.isActive
                ? const Color(0xFF4FC3F7)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
