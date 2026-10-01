import 'dart:typed_data';

/// A product photo the admin picked in the browser (file picker or Google
/// Drive). Carries everything the upload needs: original filename, bytes and
/// the MIME type the browser reported for the file.
class PickedImage {
  final String filename;
  final Uint8List bytes;
  final String contentType;

  const PickedImage({
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  /// Short human-readable size, used on the preview chip ("245 KB").
  String get sizeLabel {
    final kb = bytes.lengthInBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
