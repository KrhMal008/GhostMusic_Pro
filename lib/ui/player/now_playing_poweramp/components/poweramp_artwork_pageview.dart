import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghostmusic/domain/state/playback_controller.dart';
import '../native/airplay_route_picker.dart';

/// Poweramp-style interactive artwork with PageView swipe.
///
/// Features:
/// - Swipe left/right shows next/prev artwork during drag
/// - Track changes when page settles
/// - Preloads adjacent artwork
/// - AirPlay button overlay (top-right)
/// - Like/Dislike overlays (bottom-left)
/// - Menu overlay (bottom-right)
class PowerampArtworkPageView extends ConsumerStatefulWidget {
  final int currentIndex;
  final int queueLength;
  final String? Function(int index) getArtworkPath;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onMenuTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onDislikeTap;
  final bool isLiked;
  final bool isDisliked;

  const PowerampArtworkPageView({
    super.key,
    required this.currentIndex,
    required this.queueLength,
    required this.getArtworkPath,
    required this.onPrevious,
    required this.onNext,
    required this.onMenuTap,
    this.onLikeTap,
    this.onDislikeTap,
    this.isLiked = false,
    this.isDisliked = false,
  });

  @override
  ConsumerState<PowerampArtworkPageView> createState() => _PowerampArtworkPageViewState();
}

class _PowerampArtworkPageViewState extends ConsumerState<PowerampArtworkPageView> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.currentIndex;
    _pageController = PageController(
      initialPage: widget.currentIndex,
      viewportFraction: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant PowerampArtworkPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If track changed externally (e.g., from queue), animate to new page
    if (widget.currentIndex != _currentPage && !_isAnimating) {
      _animateToPage(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToPage(int page) {
    if (!_pageController.hasClients) return;

    _isAnimating = true;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ).then((_) {
      _isAnimating = false;
      _currentPage = page;
    });
  }

  void _onPageChanged(int page) {
    if (_isAnimating) return;

    final delta = page - widget.currentIndex;
    if (delta == 1) {
      HapticFeedback.mediumImpact();
      widget.onNext();
    } else if (delta == -1) {
      HapticFeedback.mediumImpact();
      widget.onPrevious();
    }

    _currentPage = page;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final artworkSize = screenWidth - 48; // 24px margin each side

    return SizedBox(
      width: artworkSize,
      height: artworkSize,
      child: Stack(
        children: [
          // PageView for interactive swipe
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.queueLength,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final path = widget.getArtworkPath(index);
                return _ArtworkPage(
                  artworkPath: path,
                  isCurrentPage: index == widget.currentIndex,
                );
              },
            ),
          ),

          // Shadow overlay for depth
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
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
              ),
            ),
          ),

          // Border overlay
          Positioned.fill(
            child: IgnorePointer(
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
          ),

          // AirPlay button (top-right)
          const Positioned(
            top: 12,
            right: 12,
            child: AirPlayRoutePickerButton(size: 36),
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

          // Menu (bottom-right)
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
    );
  }
}

class _ArtworkPage extends StatelessWidget {
  final String? artworkPath;
  final bool isCurrentPage;

  const _ArtworkPage({
    required this.artworkPath,
    required this.isCurrentPage,
  });

  @override
  Widget build(BuildContext context) {
    if (artworkPath == null) {
      return _placeholder();
    }

    return Image.file(
      File(artworkPath!),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2D35), Color(0xFF1A1D25)],
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
