// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// View type registered once for the embedded export-video platform view.
const String _viewType = 'medigram-export-video-player';

bool _viewRegistered = false;

/// Builds the embedded export/promo video player for Flutter web.
///
/// YouTube links (`youtube.com` / `youtu.be`) are embedded in an iframe;
/// any other URL plays in a native HTML5 `<video>` element with controls.
Widget buildExportVideoPlayer({required String videoUrl}) {
  if (!_viewRegistered) {
    _viewRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _createVideoElement(videoUrl);
    });
  }
  return const HtmlElementView(viewType: _viewType);
}

html.Element _createVideoElement(String url) {
  final bool isYouTubeEmbed =
      url.contains('youtube.com') || url.contains('youtu.be');
  if (isYouTubeEmbed) {
    return html.IFrameElement()
      ..src = url
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
      ..setAttribute('allowfullscreen', '');
  }
  final html.VideoElement video = html.VideoElement()
    ..src = url
    ..controls = true
    ..style.width = '100%'
    ..style.height = '100%';
  video.setAttribute('playsinline', '');
  video.style.setProperty('object-fit', 'cover');
  return video;
}
