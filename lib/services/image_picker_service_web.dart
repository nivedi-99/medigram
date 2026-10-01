import 'dart:async';
import 'dart:convert';

// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'product_image.dart';

/// Fallback MIME types for browsers that leave `file.type` empty.
String _typeFromExtension(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return '';
  }
}

/// Web: opens the browser file picker for images. The native dialog also
/// lists Google Drive / OneDrive, so admins can attach a photo straight from
/// the cloud. Returns the picked image, or null when the dialog was closed
/// without choosing a file.
Future<PickedImage?> pickProductImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp,image/gif,image/*'
    ..multiple = false;

  // Resolves true when a file was chosen, false on cancel. Older browsers
  // never fire the cancel event, hence the safety-valve timeout below.
  final done = Completer<bool>();
  input.onChange.listen((_) {
    if (!done.isCompleted) done.complete(true);
  });
  input.addEventListener('cancel', (html.Event _) {
    if (!done.isCompleted) done.complete(false);
  });
  input.click();

  final picked = await done.future.timeout(
    const Duration(minutes: 10),
    onTimeout: () => false,
  );
  if (!picked) return null;

  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;

  final type =
      (file.type.isNotEmpty ? file.type : _typeFromExtension(file.name))
          .toLowerCase();
  if (!type.startsWith('image/')) {
    throw const FormatException(
        'Please choose an image file (PNG, JPEG, WebP or GIF).');
  }

  // Read as a data URL ("data:image/png;base64,....") — keeps the byte
  // handling free of dart:html's ArrayBuffer typing quirks.
  final reader = html.FileReader();
  final loaded = reader.onLoadEnd.first;
  reader.readAsDataUrl(file);
  await loaded;

  final dataUrl = reader.result is String ? reader.result as String : '';
  final base64 = dataUrl.contains(',') ? dataUrl.split(',')[1] : '';
  if (base64.isEmpty) return null;

  return PickedImage(
    filename: file.name,
    bytes: base64Decode(base64),
    contentType: type,
  );
}
