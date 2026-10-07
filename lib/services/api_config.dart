import 'package:flutter/foundation.dart';

/// Points the Flutter app at the deployed MediGram API.
///
/// The app holds NO Supabase keys — every request goes through the
/// Express API on Render, which is the only holder of the service-role key.
class ApiConfig {
  ApiConfig._();

  /// Production API (Render).
  static const String productionUrl = 'https://medigram-api.onrender.com';

  /// Previous host (Railway) — retired after the trial ended.
  // static const String productionUrl =
  //     'https://medigram-api-production.up.railway.app';

  /// Local development override (uncomment while developing):
  // static const String productionUrl = 'http://localhost:4000';

  static String get baseUrl => kDebugMode
      ? const bool.fromEnvironment('USE_LOCAL_API')
          ? 'http://localhost:4000'
          : productionUrl
      : productionUrl;

  /// Everything lives under /api/v1.
  static Uri uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base/api/v1$path').replace(queryParameters: query);
  }
}
