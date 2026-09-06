import 'package:flutter/material.dart';

import 'models/models.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/home_shell.dart';
import 'screens/landing_page.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/currency_service.dart';
import 'services/theme_controller.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted tokens (localStorage on web) and the theme preference.
  await ApiClient.init();
  await ThemeController.load();

  runApp(const MediGramApp());
}

class MediGramApp extends StatefulWidget {
  const MediGramApp({super.key});

  @override
  State<MediGramApp> createState() => _MediGramAppState();
}

class _MediGramAppState extends State<MediGramApp> {
  /// Root navigator key: top-level callbacks (landing page buttons) live in
  /// a context above MaterialApp, so they navigate through this key.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Whether we are restoring the session / hydrating the profile.
  bool _restoring = true;

  /// The hydrated profile of the signed-in user (null when signed out).
  AppUser? _user;

  /// Restores the session: stored tokens -> GET /auth/me -> role routing.
  Future<void> _restoreSession() async {
    final user = await AuthService.restoreSession();
    if (!mounted) return;
    CurrencyService.configure(user?.country);
    setState(() {
      _user = user;
      _restoring = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  void _onLoginSuccess(AppUser user) {
    CurrencyService.configure(user.country);
    setState(() => _user = user);
  }

  Future<void> _onLogout() async {
    await AuthService.signOut();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          title: 'MediGram — Global Pharmaceutical Exports',
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(),
          themeMode: themeMode,
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_restoring) {
      return const _SplashScreen();
    }

    final user = _user;
    if (user == null) {
      return LandingPage(
        onLogin: () => _navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => LoginPage(onLoginSuccess: _onLoginSuccess)),
        ),
        onSignup: () => _navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => SignUpPage(onSignUpSuccess: _onLoginSuccess)),
        ),
      );
    }

    if (user.role == UserRole.superAdmin) {
      return SuperAdminDashboardPage(user: user, onLogout: _onLogout);
    }
    if (user.role == UserRole.admin) {
      return AdminDashboardPage(user: user, onLogout: _onLogout);
    }

    // Default: B2B client portal.
    return HomeShell(
      customer: user.toCustomer(),
      country: user.country,
      companyName:
          user.companyName.isEmpty ? 'MediGram B2B Client' : user.companyName,
      onLogout: _onLogout,
    );
  }
}

/// Branded splash shown while the session is restored.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_pharmacy_rounded,
                  color: Colors.white, size: 64),
              const SizedBox(height: 18),
              const Text(
                'MediGram',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Global Pharmaceutical Exports',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
