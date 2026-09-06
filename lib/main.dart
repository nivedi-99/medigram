import 'package:flutter/material.dart';

import 'models/models.dart';
import 'screens/admin/admin_dashboard_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/home_shell.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted tokens (localStorage on web) — no Supabase SDK here.
  await ApiClient.init();

  runApp(const MediGramApp());
}

class MediGramApp extends StatefulWidget {
  const MediGramApp({super.key});

  @override
  State<MediGramApp> createState() => _MediGramAppState();
}

class _MediGramAppState extends State<MediGramApp> {
  /// Whether we are restoring the session / hydrating the profile.
  bool _restoring = true;

  /// The hydrated profile of the signed-in user (null when signed out).
  AppUser? _user;

  /// Restores the session: stored tokens → GET /auth/me → role-based routing.
  Future<void> _restoreSession() async {
    final user = await AuthService.restoreSession();
    if (!mounted) return;
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
    setState(() => _user = user);
  }

  Future<void> _onLogout() async {
    await AuthService.signOut();
    if (!mounted) return;
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediGram — Global Pharmaceutical Exports',
      theme: buildAppTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_restoring) {
      return const _SplashScreen();
    }

    final user = _user;
    if (user == null) {
      return LoginPage(onLoginSuccess: _onLoginSuccess);
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
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 64),
              SizedBox(height: 18),
              Text(
                'MediGram',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Global Pharmaceutical Exports',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 28),
              SizedBox(
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
