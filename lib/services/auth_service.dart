import '../models/models.dart';
import 'api_client.dart';

/// Authentication service — talks to the MediGram API (Render).
///
/// Method signatures match the previous Supabase-backed implementation so
/// the screens did not change. Exceptions are [ApiException].
class AuthService {
  AuthService._();

  /// The hydrated profile of the signed-in user.
  static AppUser? currentUser;

  static bool get isSignedIn => currentUser != null;

  static AppUser _userFrom(Map<String, dynamic> map) {
    final user = AppUser.fromMap(map);
    currentUser = user;
    return user;
  }

  /// Restores the session from persisted tokens (call at startup).
  /// Returns the user, or null when there is no valid session.
  static Future<AppUser?> restoreSession() async {
    if (!ApiClient.hasSession) return null;
    try {
      final body = await ApiClient.get('/auth/me');
      return _userFrom(body['data']['user'] as Map<String, dynamic>);
    } on ApiException {
      // 401: ApiClient already attempted a refresh; treat as signed out.
      await ApiClient.clearSession();
      currentUser = null;
      return null;
    }
  }

  /// P6 · signs in with email + password and stores the session.
  static Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final body = await ApiClient.post('/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    final data = body['data'] as Map<String, dynamic>;
    await ApiClient.setTokens(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    return _userFrom(data['user'] as Map<String, dynamic>);
  }

  /// P1 · registers a new B2B client (then signs them in).
  static Future<AppUser> signUpClient({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String companyName,
    required String country,
    String businessLicenseNo = '',
  }) async {
    await ApiClient.post('/auth/signup', body: {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone.trim(),
      'companyName': companyName.trim(),
      'country': country.trim(),
      if (businessLicenseNo.isNotEmpty) 'businessLicenseNo': businessLicenseNo.trim(),
    });
    // Auto sign-in so the user lands straight into the portal.
    return signIn(email: email, password: password);
  }

  /// Hydrates the signed-in profile from the API.
  static Future<AppUser> fetchProfile() async {
    final body = await ApiClient.get('/auth/me');
    return _userFrom(body['data']['user'] as Map<String, dynamic>);
  }

  /// PATCH /profile — updates the signed-in user's own fields.
  static Future<AppUser> updateProfile({
    required String fullName,
    required String phone,
    String? companyName,
    String? country,
  }) async {
    final body = await ApiClient.patch('/profile', body: {
      'fullName': fullName,
      'phone': phone,
      if (companyName != null) 'companyName': companyName,
      if (country != null) 'country': country,
    });
    return _userFrom(body['data']['user'] as Map<String, dynamic>);
  }

  /// Always succeeds from the caller's perspective (anti-enumeration).
  static Future<void> resetPassword(String email) async {
    await ApiClient.post('/auth/forgot-password', body: {'email': email.trim()});
  }

  /// Revokes the session server-side and clears local tokens.
  static Future<void> signOut() async {
    try {
      await ApiClient.post('/auth/logout');
    } on ApiException {
      // Token already expired — treat as logged out.
    }
    await ApiClient.clearSession();
    currentUser = null;
  }
}
