import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:ghostmusic/domain/services/track_actions_service.dart';
import 'package:ghostmusic/ui/artwork/cover_picker_sheet.dart';
import 'package:ghostmusic/ui/library/tag_editor_sheet.dart';

/// Poweramp-style track context menu with all actions.
///
/// Actions:
/// - Cover Art picker
/// - Edit Tags
/// - Move to Folder (restored)
/// - Add to Playlist
/// - Go to Album/Artist/Folder
/// - Share
/// - Track Info
class PowerampTrackMenu extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                TrackActionsService.showMoveToFolderPicker(
                  context: context,
                  ref: ref,
                  trackPath: trackPath,
                );
              },
            ),

            _MenuItem(
              icon: Icons.playlist_add_rounded,
              title: 'Add to Playlist...',
              onTap: () {
                Navigator.of(context).pop();
                TrackActionsService.showPlaylistPicker(
                  context: context,
                  trackPath: trackPath,
                );
              },
            ),

            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

            _MenuItem(
              icon: Icons.album_rounded,
              title: 'Go to Album',
              onTap: () {
                Navigator.of(context).pop();
                TrackActionsService.goToAlbum(
                  context: context,
                  ref: ref,
                  trackPath: trackPath,
                );
              },
            ),

            _MenuItem(
              icon: Icons.person_rounded,
              title: 'Go to Artist',
              onTap: () {
                Navigator.of(context).pop();
                TrackActionsService.goToArtist(
                  context: context,
                  ref: ref,
                  trackPath: trackPath,
                );
              },
            ),

            _MenuItem(
              icon: Icons.folder_rounded,
              title: 'Go to Folder',
              onTap: () {
                Navigator.of(context).pop();
                TrackActionsService.goToFolder(
                  context: context,
                  ref: ref,
                  trackPath: trackPath,
                );
              },
            ),

            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

            _MenuItem(
              icon: Icons.share_rounded,
              title: 'Share...',
              onTap: () {
                Navigator.of(context).pop();
                TrackActionsService.shareTrack(
                  context: context,
                  trackPath: trackPath,
                );
              },
            ),

            _MenuItem(
              icon: Icons.info_outline_rounded,
              title: 'Track Info',
              onTap: () {
                Navigator.of(context).pop();
                TrackActionsService.showTrackInfo(
                  context: context,
                  trackPath: trackPath,
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
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
