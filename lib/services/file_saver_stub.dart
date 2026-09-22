import 'dart:io';

/// Non-web: writes the download to the system temp folder and returns the
/// full path (the deployed build is web-only; this keeps analysis clean).
Future<String> saveDownload(String filename, List<int> bytes) async {
  final path =
      '${Directory.systemTemp.path}${Platform.pathSeparator}$filename';
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
