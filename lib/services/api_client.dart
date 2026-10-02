import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

/// Typed API failure — thrown by every ApiClient call.
class ApiException implements Exception {
  final int status;
  final String code;
  final String message;

  const ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

/// Thin HTTP client for the MediGram API.
///
/// * Attaches `Authorization: Bearer <accessToken>` to every request.
/// * On 401 it refreshes the session once and retries.
/// * Persists tokens in SharedPreferences (localStorage on web) so the
///   session survives reloads.
/// * Parses the API's `{ "error": { "code", "message" } }` envelope into
///   [ApiException].
class ApiClient {
  ApiClient._();

  static const _prefsKeyAccess = 'mg_access_token';
  static const _prefsKeyRefresh = 'mg_refresh_token';

  static String? _accessToken;
  static String? _refreshToken;
  static http.Client? _http;

  static http.Client get _client => _http ??= http.Client();

  static bool get hasSession => _accessToken != null;

  /// Loads persisted tokens (call once at startup).
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_prefsKeyAccess);
    _refreshToken = prefs.getString(_prefsKeyRefresh);
  }

  static Future<void> _persist(String access, String? refresh) async {
    _accessToken = access;
    if (refresh != null) _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyAccess, access);
    if (refresh != null) await prefs.setString(_prefsKeyRefresh, refresh);
  }

  static Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyAccess);
    await prefs.remove(_prefsKeyRefresh);
  }

  static Future<void> setTokens(String access, String refresh) async =>
      _persist(access, refresh);

  /// Refreshes the session; returns true when a new access token is stored.
  static Future<bool> refreshSession() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _client.post(
        ApiConfig.uri('/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (res.statusCode != 200) return false;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      await _persist(
          data['accessToken'] as String, data['refreshToken'] as String?);
      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------
  // Core request helpers
  // -------------------------------------------------------------------

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    bool retryOn401 = true,
  }) async {
    final uri = ApiConfig.uri(path, query);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    final res = await _client
        .send(http.Request(method, uri)
          ..headers.addAll(headers)
          ..body = body == null ? '' : jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401 && auth && retryOn401) {
      final refreshed = await refreshSession();
      if (refreshed) {
        return _send(method, path,
            body: body, query: query, auth: auth, retryOn401: false);
      }
      await clearSession();
      throw const ApiException(
          401, 'UNAUTHORIZED', 'Session expired — please sign in again.');
    }

    final text = await res.stream.bytesToString();
    Map<String, dynamic> decoded = {};
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        decoded = {'raw': text};
      }
    }

    if (res.statusCode >= 400) {
      final err = decoded['error'] as Map<String, dynamic>?;
      throw ApiException(
        res.statusCode,
        err?['code']?.toString() ?? 'HTTP_${res.statusCode}',
        err?['message']?.toString() ?? 'Request failed (${res.statusCode})',
      );
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> get(String path,
          {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  /// GET returning the raw response body (CSV exports). Same 401 -> refresh
  /// -> single-retry behaviour as [_send].
  static Future<String> getText(
    String path, {
    Map<String, String>? query,
    bool retryOn401 = true,
  }) async {
    final uri = ApiConfig.uri(path, query);
    final headers = <String, String>{};
    if (_accessToken != null) headers['Authorization'] = 'Bearer $_accessToken';

    final res = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401 && retryOn401) {
      final refreshed = await refreshSession();
      if (refreshed) return getText(path, query: query, retryOn401: false);
      await clearSession();
      throw const ApiException(
          401, 'UNAUTHORIZED', 'Session expired - please sign in again.');
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, 'HTTP_${res.statusCode}',
          'Download failed (${res.statusCode})');
    }
    return utf8.decode(res.bodyBytes);
  }

  static Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  static Future<Map<String, dynamic>> patch(String path,
          {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body);

  static Future<Map<String, dynamic>> put(String path,
          {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  static Future<Map<String, dynamic>> delete(String path) =>
      _send('DELETE', path);

  /// Uploads a binary file (product photos) as a raw POST body. The API
  /// reads it with `express.raw({ type: 'image/*' })`, so the file's real
  /// MIME type must be the request content-type; the original filename
  /// travels in `x-filename` (ASCII-sanitised for the header). Uses the same
  /// session + 401 -> refresh -> single-retry behaviour as [_send].
  static Future<Map<String, dynamic>> upload(
    String path, {
    required String filename,
    required List<int> bytes,
    required String contentType,
    Map<String, String>? headers,
    bool retryOn401 = true,
  }) async {
    final uri = ApiConfig.uri(path);
    final safeName = filename.replaceAll(RegExp(r'[^\x20-\x7E]'), '_');
    final requestHeaders = <String, String>{
      'Content-Type': contentType,
      'x-filename': safeName,
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      ...?headers,
    };

    final res = await _client
        .post(uri, headers: requestHeaders, body: bytes)
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 401 && retryOn401) {
      final refreshed = await refreshSession();
      if (refreshed) {
        return upload(path,
            filename: filename,
            bytes: bytes,
            contentType: contentType,
            headers: headers,
            retryOn401: false);
      }
      await clearSession();
      throw const ApiException(
          401, 'UNAUTHORIZED', 'Session expired — please sign in again.');
    }

    Map<String, dynamic> decoded = {};
    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        decoded = {'raw': res.body};
      }
    }
    if (res.statusCode >= 400) {
      final err = decoded['error'] as Map<String, dynamic>?;
      throw ApiException(
        res.statusCode,
        err?['code']?.toString() ?? 'HTTP_${res.statusCode}',
        err?['message']?.toString() ?? 'Upload failed (${res.statusCode})',
      );
    }
    return decoded;
  }
}
