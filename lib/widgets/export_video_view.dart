/// Dashboard export/promo video embed.
///
/// The player is platform-switched the same way as the other web-only
/// services in this app (see services/file_saver.dart): a real embedded
/// video player on Flutter web and a styled placeholder on other targets.
library;

export 'export_video_view_stub.dart'
    if (dart.library.html) 'export_video_view_web.dart';
