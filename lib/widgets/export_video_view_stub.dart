import 'package:flutter/material.dart';

/// Non-web placeholder for the dashboard export/promo video card
/// (the embedded player is a web-only platform view).
Widget buildExportVideoPlayer({required String videoUrl}) {
  return Container(
    color: const Color(0xFF05353F),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Export tour video',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Video playback is available on the web app',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11.5,
          ),
        ),
      ],
    ),
  );
}
