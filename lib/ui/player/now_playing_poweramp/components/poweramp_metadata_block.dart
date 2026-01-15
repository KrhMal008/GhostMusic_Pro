import 'package:flutter/material.dart';

/// Poweramp-style metadata block (left-aligned title and subtitle).
///
/// Layout matches reference:
/// - Title: large, bold-ish, white
/// - Subtitle: smaller, lower contrast (artist - album)
class PowerampMetadataBlock extends StatelessWidget {
  final String title;
  final String? artist;
  final String? album;

  const PowerampMetadataBlock({
    super.key,
    required this.title,
    this.artist,
    this.album,
  });

  @override
  Widget build(BuildContext context) {
    // Build subtitle from artist and album
    final parts = <String>[];
    if (artist != null && artist!.trim().isNotEmpty) {
      parts.add(artist!.trim());
    }
    if (album != null && album!.trim().isNotEmpty && album != artist) {
      parts.add(album!.trim());
    }
    final subtitle = parts.isEmpty ? null : parts.join(' - ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 6),
            // Subtitle (artist - album)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.60),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
