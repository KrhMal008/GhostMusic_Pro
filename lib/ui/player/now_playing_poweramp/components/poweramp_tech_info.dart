import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Poweramp-style technical audio info line.
///
/// Displays: "24 BIT 96 KHZ 2391 KBPS FLAC CUE"
/// Small font, subtle opacity, centered.
class PowerampTechInfo extends StatelessWidget {
  final String trackPath;
  final int? bitDepth;
  final int? sampleRateHz;
  final int? bitrateKbps;
  final bool isCue;

  const PowerampTechInfo({
    super.key,
    required this.trackPath,
    this.bitDepth,
    this.sampleRateHz,
    this.bitrateKbps,
    this.isCue = false,
  });

  @override
  Widget build(BuildContext context) {
    final info = _buildTechInfo();
    if (info.isEmpty) return const SizedBox.shrink();

    return Center(
      child: Text(
        info,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.40),
          letterSpacing: 1.3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _buildTechInfo() {
    final ext = p.extension(trackPath).replaceFirst('.', '').toUpperCase();
    if (ext.isEmpty) return '';

    final parts = <String>[];

    // Bit depth (if known or inferred from format)
    if (bitDepth != null) {
      parts.add('$bitDepth BIT');
    } else if (_isLosslessFormat(ext)) {
      parts.add('24 BIT'); // Assume high quality for lossless
    }

    // Sample rate
    if (sampleRateHz != null) {
      final khz = sampleRateHz! ~/ 1000;
      final decimal = (sampleRateHz! % 1000) ~/ 100;
      if (decimal > 0) {
        parts.add('$khz.$decimal KHZ');
      } else {
        parts.add('$khz KHZ');
      }
    } else {
      // Default sample rates by format
      parts.add(_defaultSampleRate(ext));
    }

    // Bitrate (if known)
    if (bitrateKbps != null) {
      parts.add('$bitrateKbps KBPS');
    } else if (!_isLosslessFormat(ext)) {
      parts.add(_defaultBitrate(ext));
    }

    // Format
    parts.add(ext);

    // CUE indicator
    if (isCue) {
      parts.add('CUE');
    }

    return parts.where((p) => p.isNotEmpty).join('  ');
  }

  bool _isLosslessFormat(String ext) {
    return ['FLAC', 'WAV', 'AIF', 'AIFF', 'APE', 'WV', 'ALAC'].contains(ext);
  }

  String _defaultSampleRate(String ext) {
    switch (ext) {
      case 'FLAC':
      case 'WAV':
      case 'AIF':
      case 'AIFF':
        return '96 KHZ';
      case 'MP3':
      case 'M4A':
      case 'AAC':
        return '44.1 KHZ';
      case 'OGG':
      case 'OPUS':
        return '48 KHZ';
      default:
        return '44.1 KHZ';
    }
  }

  String _defaultBitrate(String ext) {
    switch (ext) {
      case 'MP3':
        return '320 KBPS';
      case 'M4A':
      case 'AAC':
        return '256 KBPS';
      case 'OGG':
        return '192 KBPS';
      case 'OPUS':
        return '128 KBPS';
      default:
        return '';
    }
  }
}
