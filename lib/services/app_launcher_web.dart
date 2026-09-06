// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Opens [url] in a new browser tab. Web implementation.
Future<bool> openExternalUrl(String url) async {
  html.window.open(url, '_blank');
  return true;
}