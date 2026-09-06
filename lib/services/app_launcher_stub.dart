/// Non-web platforms: this build ships web-only, so opening is a no-op that
/// reports failure (callers show a friendly message).
Future<bool> openExternalUrl(String url) async {
  return false;
}