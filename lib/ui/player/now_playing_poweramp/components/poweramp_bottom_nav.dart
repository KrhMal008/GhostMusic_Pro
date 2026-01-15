import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Poweramp-style bottom navigation bar.
///
/// 4 icons in a pill-like container:
/// - Library (grid)
/// - EQ (bars)
/// - Search
/// - Menu (list)
class PowerampBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const PowerampBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.grid_view_rounded,
            isSelected: selectedIndex == 0,
            onTap: () => onTap(0),
            label: 'Library',
          ),
          _NavItem(
            icon: Icons.equalizer_rounded,
            isSelected: selectedIndex == 1,
            onTap: () => onTap(1),
            label: 'EQ',
          ),
          _NavItem(
            icon: Icons.search_rounded,
            isSelected: selectedIndex == 2,
            onTap: () => onTap(2),
            label: 'Search',
          ),
          _NavItem(
            icon: Icons.menu_rounded,
            isSelected: selectedIndex == 3,
            onTap: () => onTap(3),
            label: 'Menu',
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String label;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.50);

    return Tooltip(
      message: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: 52,
            height: 44,
            decoration: widget.isSelected
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            child: Icon(
              widget.icon,
              size: 24,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
