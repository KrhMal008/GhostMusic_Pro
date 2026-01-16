// track_actions_service.dart
//
// Ghost Music - Centralized Track Actions Service
//
// Provides a shared executor for all track-related actions:
// - Move to folder (iOS + Windows)
// - Add to playlist
// - Go to Album/Artist/Folder navigation
// - Share (iOS native + Windows fallback)
// - Track info display

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../models/track.dart';
import '../state/library_controller.dart';
import '../state/playback_controller.dart';
import 'metadata_service.dart';

/// Result of a track action execution
enum TrackActionResult {
  success,
  cancelled,
  error,
}

/// Centralized service for all track-related actions
class TrackActionsService {
  TrackActionsService._();

  // ===========================================================================
  // Move to Folder
  // ===========================================================================

  /// Move a track file to a new folder
  /// Returns the new file path on success, null on failure/cancel
  static Future<String?> moveToFolder({
    required BuildContext context,
    required String trackPath,
    required String destinationFolder,
  }) async {
    try {
      final sourceFile = File(trackPath);
      if (!await sourceFile.exists()) {
        if (context.mounted) _showError(context, 'Source file not found');
        return null;
      }

      final fileName = p.basename(trackPath);
      final destinationPath = p.join(destinationFolder, fileName);

      // Check if destination already exists
      final destFile = File(destinationPath);
      if (await destFile.exists()) {
        if (!context.mounted) return null;
        final overwrite = await _showConfirmDialog(
          context,
          title: 'File exists',
          message: 'A file with this name already exists in the destination. Overwrite?',
        );
        if (!overwrite) return null;
        await destFile.delete();
      }

      // Move the file
      if (Platform.isWindows) {
        // On Windows, File.rename works across drives
        await sourceFile.rename(destinationPath);
      } else {
        // On iOS/macOS, copy then delete for cross-volume moves
        await sourceFile.copy(destinationPath);
        await sourceFile.delete();
      }

      if (context.mounted) _showSuccess(context, 'Moved to ${p.basename(destinationFolder)}');
      return destinationPath;
    } catch (e) {
      if (context.mounted) _showError(context, 'Move failed: $e');
      return null;
    }
  }

  /// Show folder picker for moving a track
  static Future<String?> showMoveToFolderPicker({
    required BuildContext context,
    required WidgetRef ref,
    required String trackPath,
  }) async {
    // Get library folders as potential destinations
    final libraryState = ref.read(libraryControllerProvider);
    final folders = libraryState.folders;

    if (folders.isEmpty) {
      if (context.mounted) _showError(context, 'No library folders configured');
      return null;
    }

    final currentFolder = p.dirname(trackPath);

    if (!context.mounted) return null;
    final selectedFolder = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _MoveToFolderSheet(
        currentFolder: currentFolder,
        libraryFolders: folders,
      ),
    );

    if (selectedFolder == null || !context.mounted) return null;

    return moveToFolder(
      context: context,
      trackPath: trackPath,
      destinationFolder: selectedFolder,
    );
  }

  // ===========================================================================
  // Add to Playlist (placeholder - needs playlist system)
  // ===========================================================================

  /// Add track to a playlist
  static Future<TrackActionResult> addToPlaylist({
    required BuildContext context,
    required String trackPath,
    String? playlistId,
  }) async {
    // TODO: Implement when playlist system is added
    HapticFeedback.selectionClick();
    _showInfo(context, 'Playlists coming soon');
    return TrackActionResult.cancelled;
  }

  /// Show playlist picker sheet
  static Future<void> showPlaylistPicker({
    required BuildContext context,
    required String trackPath,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlaylistPickerSheet(trackPath: trackPath),
    );
  }

  // ===========================================================================
  // Navigation: Go to Album/Artist/Folder
  // ===========================================================================

  /// Navigate to the folder containing the track
  static Future<void> goToFolder({
    required BuildContext context,
    required WidgetRef ref,
    required String trackPath,
  }) async {
    HapticFeedback.selectionClick();

    final folderPath = p.dirname(trackPath);
    final libraryState = ref.read(libraryControllerProvider);

    // Find tracks in the same folder
    final folderTracks = libraryState.tracks
        .where((t) => p.dirname(t.filePath) == folderPath)
        .toList();

    if (folderTracks.isEmpty) {
      if (context.mounted) _showError(context, 'No tracks found in folder');
      return;
    }

    if (!context.mounted) return;

    // Close any open sheets/dialogs first
    Navigator.of(context).popUntil((route) => route.isFirst);

    // TODO: Navigate to folder browser with this folder selected
    // For now, show a snackbar with folder name
    if (context.mounted) _showInfo(context, 'Folder: ${p.basename(folderPath)}');
  }

  /// Navigate to tracks by the same artist
  static Future<void> goToArtist({
    required BuildContext context,
    required WidgetRef ref,
    required String trackPath,
  }) async {
    HapticFeedback.selectionClick();

    // Get track metadata to find artist
    final playbackState = ref.read(playbackControllerProvider);
    Track? track;

    // Try to find track in current queue first
    for (final t in playbackState.queue) {
      if (t.filePath == trackPath) {
        track = t;
        break;
      }
    }

    // Fallback to library
    if (track == null) {
      final libraryState = ref.read(libraryControllerProvider);
      for (final t in libraryState.tracks) {
        if (t.filePath == trackPath) {
          track = t;
          break;
        }
      }
    }

    final artist = track?.artist;
    if (artist == null || artist.isEmpty) {
      if (context.mounted) _showError(context, 'Artist not available');
      return;
    }

    // Find all tracks by this artist
    final libraryState = ref.read(libraryControllerProvider);
    final artistTracks = libraryState.tracks
        .where((t) => t.artist?.toLowerCase() == artist.toLowerCase())
        .toList();

    if (!context.mounted) return;

    // Close any open sheets/dialogs
    Navigator.of(context).popUntil((route) => route.isFirst);

    // TODO: Navigate to artist view
    if (context.mounted) _showInfo(context, 'Artist: $artist (${artistTracks.length} tracks)');
  }

  /// Navigate to tracks in the same album
  static Future<void> goToAlbum({
    required BuildContext context,
    required WidgetRef ref,
    required String trackPath,
  }) async {
    HapticFeedback.selectionClick();

    // Get track metadata to find album
    final playbackState = ref.read(playbackControllerProvider);
    Track? track;

    for (final t in playbackState.queue) {
      if (t.filePath == trackPath) {
        track = t;
        break;
      }
    }

    if (track == null) {
      final libraryState = ref.read(libraryControllerProvider);
      for (final t in libraryState.tracks) {
        if (t.filePath == trackPath) {
          track = t;
          break;
        }
      }
    }

    final album = track?.album;
    if (album == null || album.isEmpty) {
      if (context.mounted) _showError(context, 'Album not available');
      return;
    }

    // Find all tracks in this album
    final libraryState = ref.read(libraryControllerProvider);
    final albumTracks = libraryState.tracks
        .where((t) => t.album?.toLowerCase() == album.toLowerCase())
        .toList();

    if (!context.mounted) return;

    // Close any open sheets/dialogs
    Navigator.of(context).popUntil((route) => route.isFirst);

    // TODO: Navigate to album view
    if (context.mounted) _showInfo(context, 'Album: $album (${albumTracks.length} tracks)');
  }

  // ===========================================================================
  // Share
  // ===========================================================================

  /// Share a track file
  static Future<TrackActionResult> shareTrack({
    required BuildContext context,
    required String trackPath,
  }) async {
    HapticFeedback.selectionClick();

    try {
      final file = File(trackPath);
      if (!await file.exists()) {
        if (context.mounted) _showError(context, 'File not found');
        return TrackActionResult.error;
      }

      if (Platform.isIOS) {
        // Use native iOS share sheet
        await Share.shareXFiles(
          [XFile(trackPath)],
          subject: p.basenameWithoutExtension(trackPath),
        );
      } else if (Platform.isWindows) {
        // On Windows, open the folder containing the file in Explorer and select the file
        try {
          // Use explorer /select to open folder and highlight the file
          await Process.run('explorer', ['/select,', trackPath]);
          if (context.mounted) _showInfo(context, 'Opened in Explorer');
        } catch (_) {
          // Fallback: copy path to clipboard
          await Clipboard.setData(ClipboardData(text: trackPath));
          if (context.mounted) _showInfo(context, 'Path copied to clipboard');
        }
      } else {
        // Other platforms: use share_plus
        await Share.shareXFiles(
          [XFile(trackPath)],
          subject: p.basenameWithoutExtension(trackPath),
        );
      }

      return TrackActionResult.success;
    } catch (e) {
      if (context.mounted) _showError(context, 'Share failed: $e');
      return TrackActionResult.error;
    }
  }

  // ===========================================================================
  // Track Info
  // ===========================================================================

  /// Show detailed track info sheet
  static Future<void> showTrackInfo({
    required BuildContext context,
    required String trackPath,
  }) async {
    HapticFeedback.selectionClick();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _TrackInfoSheet(trackPath: trackPath),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  static void _showSuccess(BuildContext context, String message) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2D35),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Color(0xFFE53935), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2D35),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A2D35),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1E24),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ===========================================================================
// UI Components
// ===========================================================================

/// Sheet for selecting destination folder
class _MoveToFolderSheet extends StatefulWidget {
  final String currentFolder;
  final List<String> libraryFolders;

  const _MoveToFolderSheet({
    required this.currentFolder,
    required this.libraryFolders,
  });

  @override
  State<_MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends State<_MoveToFolderSheet> {
  List<Directory> _subfolders = [];
  String _currentPath = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.libraryFolders.isNotEmpty ? widget.libraryFolders.first : '';
    _loadSubfolders();
  }

  Future<void> _loadSubfolders() async {
    setState(() => _loading = true);

    try {
      final dir = Directory(_currentPath);
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        final folders = entities
            .whereType<Directory>()
            .where((d) => !p.basename(d.path).startsWith('.'))
            .toList()
          ..sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));

        setState(() {
          _subfolders = folders;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _subfolders = [];
        _loading = false;
      });
    }
  }

  void _navigateTo(String path) {
    setState(() => _currentPath = path);
    _loadSubfolders();
  }

  void _navigateUp() {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath && widget.libraryFolders.any((f) => parent.startsWith(f) || f.startsWith(parent))) {
      _navigateTo(parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _navigateUp,
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Move to Folder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          Text(
                            p.basename(_currentPath),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(_currentPath),
                      child: const Text('Select'),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),

              // Folder list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _subfolders.isEmpty
                        ? Center(
                            child: Text(
                              'No subfolders',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _subfolders.length,
                            itemBuilder: (context, index) {
                              final folder = _subfolders[index];
                              final name = p.basename(folder.path);
                              final isCurrentFolder = folder.path == widget.currentFolder;

                              return ListTile(
                                leading: Icon(
                                  Icons.folder_rounded,
                                  color: isCurrentFolder
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : const Color(0xFF4FC3F7),
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: isCurrentFolder
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : Colors.white,
                                  ),
                                ),
                                subtitle: isCurrentFolder
                                    ? Text(
                                        'Current location',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                      )
                                    : null,
                                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                                onTap: isCurrentFolder ? null : () => _navigateTo(folder.path),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sheet for playlist selection (placeholder)
class _PlaylistPickerSheet extends StatelessWidget {
  final String trackPath;

  const _PlaylistPickerSheet({required this.trackPath});

  @override
  Widget build(BuildContext context) {
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
              'Playlists feature coming soon!',
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
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlists coming soon'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF2A2D35),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
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
          mainAxisAlignment: MainAxisAlignment.center,
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

/// Sheet showing detailed track information
class _TrackInfoSheet extends StatefulWidget {
  final String trackPath;

  const _TrackInfoSheet({required this.trackPath});

  @override
  State<_TrackInfoSheet> createState() => _TrackInfoSheetState();
}

class _TrackInfoSheetState extends State<_TrackInfoSheet> {
  Map<String, String> _info = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final file = File(widget.trackPath);
    final fileName = p.basename(widget.trackPath);
    final folderPath = p.dirname(widget.trackPath);
    final folderName = p.basename(folderPath);
    final extension = p.extension(widget.trackPath).toUpperCase().replaceFirst('.', '');

    String fileSize = 'Unknown';
    String lastModified = 'Unknown';

    try {
      if (await file.exists()) {
        final stat = await file.stat();
        fileSize = _formatFileSize(stat.size);
        lastModified = _formatDate(stat.modified);
      }
    } catch (_) {}

    // Try to get metadata
    String? title, artist, album, duration;
    try {
      final track = Track(filePath: widget.trackPath);
      final result = await MetadataService.enrichTrack(track);
      title = result.track.title;
      artist = result.track.artist;
      album = result.track.album;
      if (result.track.duration != null) {
        duration = _formatDuration(result.track.duration!);
      }
    } catch (_) {}

    setState(() {
      _info = {
        'File Name': fileName,
        'Folder': folderName,
        'Format': extension,
        'File Size': fileSize,
        'Last Modified': lastModified,
        if (title != null && title.isNotEmpty) 'Title': title,
        if (artist != null && artist.isNotEmpty) 'Artist': artist,
        if (album != null && album.isNotEmpty) 'Album': album,
        if (duration != null) 'Duration': duration,
        'Full Path': widget.trackPath,
      };
      _loading = false;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 24,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Track Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scrollController,
                          children: _info.entries
                              .map((e) => _InfoRow(label: e.key, value: e.value))
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

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
