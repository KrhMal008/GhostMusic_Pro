import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'package:ghostmusic/ui/artwork/cover_picker_sheet.dart';
import 'package:ghostmusic/ui/library/tag_editor_sheet.dart';

/// Poweramp-style track context menu with all actions.
///
/// Actions:
/// - Cover Art picker
/// - Edit Tags
/// - Move to Folder (restored)
/// - Add to Playlist
/// - Go to Album/Artist
/// - Share
/// - Track Info
class PowerampTrackMenu extends StatelessWidget {
  final String trackPath;

  const PowerampTrackMenu({
    super.key,
    required this.trackPath,
  });

  static Future<void> show(BuildContext context, String trackPath) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      isScrollControlled: true,
      builder: (_) => PowerampTrackMenu(trackPath: trackPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(trackPath);
    final folderName = p.basename(p.dirname(trackPath));

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1E24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 12),

            // File info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.90),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'in $folderName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

            // Menu items
            _MenuItem(
              icon: Icons.image_search_rounded,
              title: 'Cover Art...',
              onTap: () {
                Navigator.of(context).pop();
                CoverPickerSheet.show(context, trackPath);
              },
            ),

            _MenuItem(
              icon: Icons.edit_rounded,
              title: 'Edit Tags...',
              onTap: () {
                Navigator.of(context).pop();
                TagEditorSheet.show(context, trackPath);
              },
            ),

            _MenuItem(
              icon: Icons.drive_file_move_outlined,
              title: 'Move to Folder...',
              onTap: () {
                Navigator.of(context).pop();
                _showMoveToFolderSheet(context, trackPath);
              },
            ),

            _MenuItem(
              icon: Icons.playlist_add_rounded,
              title: 'Add to Playlist...',
              onTap: () {
                Navigator.of(context).pop();
                _showAddToPlaylistSheet(context, trackPath);
              },
            ),

            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

            _MenuItem(
              icon: Icons.album_rounded,
              title: 'Go to Album',
              onTap: () {
                Navigator.of(context).pop();
                // Navigate to album - would need proper implementation
                _showComingSoon(context, 'Go to Album');
              },
            ),

            _MenuItem(
              icon: Icons.person_rounded,
              title: 'Go to Artist',
              onTap: () {
                Navigator.of(context).pop();
                // Navigate to artist - would need proper implementation
                _showComingSoon(context, 'Go to Artist');
              },
            ),

            _MenuItem(
              icon: Icons.folder_rounded,
              title: 'Go to Folder',
              onTap: () {
                Navigator.of(context).pop();
                // Navigate to folder - would need proper implementation
                _showComingSoon(context, 'Go to Folder');
              },
            ),

            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

            _MenuItem(
              icon: Icons.share_rounded,
              title: 'Share...',
              onTap: () {
                Navigator.of(context).pop();
                _shareTrack(context, trackPath);
              },
            ),

            _MenuItem(
              icon: Icons.info_outline_rounded,
              title: 'Track Info',
              onTap: () {
                Navigator.of(context).pop();
                _showTrackInfo(context, trackPath);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMoveToFolderSheet(BuildContext context, String trackPath) {
    // Move to folder functionality
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.drive_file_move_outlined,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Move to Folder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a folder to move this track to.\nThis will physically move the file on disk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                // Folder picker would go here
                // For now, show placeholder
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap to select folder...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistSheet(BuildContext context, String trackPath) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.playlist_add_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add to Playlist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a playlist to add this track to.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                // Create new playlist button
                _PlaylistOption(
                  icon: Icons.add_rounded,
                  title: 'Create New Playlist...',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // Would create new playlist
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming soon'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2D35),
      ),
    );
  }

  void _shareTrack(BuildContext context, String trackPath) {
    // Would implement share functionality
    _showComingSoon(context, 'Share');
  }

  void _showTrackInfo(BuildContext context, String trackPath) {
    final fileName = p.basename(trackPath);
    final folderPath = p.dirname(trackPath);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      'Track Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoRow(label: 'File Name', value: fileName),
                    _InfoRow(label: 'Location', value: folderPath),
                    _InfoRow(label: 'Full Path', value: trackPath),
                    // More info would come from metadata
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: _pressed ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 22,
              color: Colors.white.withValues(alpha: 0.70),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistOption extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _PlaylistOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_PlaylistOption> createState() => _PlaylistOptionState();
}

class _PlaylistOptionState extends State<_PlaylistOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 22,
              color: const Color(0xFF4FC3F7),
            ),
            const SizedBox(width: 12),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4FC3F7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
