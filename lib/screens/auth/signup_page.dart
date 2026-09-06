import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

/// B2B client registration. Creates the auth user plus `profiles` and
/// `client_profiles` rows in Supabase; verification is then handled by an
/// admin from the admin dashboard.
class SignUpPage extends StatefulWidget {
  final void Function(AppUser user) onSignUpSuccess;

  const SignUpPage({super.key, required this.onSignUpSuccess});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _countryController = TextEditingController();
  final _licenseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final bool _obscure = true;
  bool _agreed = false;
  bool _submitting = false;

  static final _countries = [
    'United States', 'United Kingdom', 'Germany', 'France', 'Netherlands',
    'United Arab Emirates', 'Saudi Arabia', 'Nigeria', 'Kenya', 'South Africa',
    'Brazil', 'Mexico', 'Australia', 'Japan', 'Singapore', 'India', 'Other',
  ];

  String? _selectedCountry;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _countryController.dispose();
    _licenseController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      _showError('Please accept the Terms & Privacy Policy');
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = await AuthService.signUpClient(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
        companyName: _companyController.text,
        country: _selectedCountry ?? '',
        businessLicenseNo: _licenseController.text,
      );
      if (!mounted) return;
      widget.onSignUpSuccess(user);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: AppColors.textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Register your business',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create a B2B client account to source pharmaceuticals,\nrequest export quotes and track shipments worldwide.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Full name',
                controller: _nameController,
                hint: 'Jane Doe',
                icon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              // __SIGNUP_FIELDS__
              LabeledField(
                label: 'Company name',
                controller: _companyController,
                hint: 'Global Pharma Traders Ltd.',
                icon: Icons.business_rounded,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your company name'
                    : null,
              ),
              LabeledField(
                label: 'Business email',
                controller: _emailController,
                hint: 'you@company.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              LabeledField(
                label: 'Phone / WhatsApp',
                controller: _phoneController,
                hint: '+1 555 000 1234',
                icon: Icons.call_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 7)
                    ? 'Enter a valid contact number'
                    : null,
              ),
              const SizedBox(height: 7),
              Text(
                'Country',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                initialValue: _selectedCountry,
                decoration: InputDecoration(
                  hintText: 'Select your country',
                  prefixIcon: Icon(
                    Icons.public_rounded,
                    size: 20,
                    color: AppColors.blueDark,
                  ),
                ),
                items: _countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCountry = v),
                validator: (v) =>
                    v == null ? 'Please select your country' : null,
              ),
              // __SIGNUP_FIELDS2__
              LabeledField(
                label: 'Business / import license no. (optional)',
                controller: _licenseController,
                hint: 'e.g. PHARMA-IMP-2024-0091',
                icon: Icons.badge_outlined,
              ),
              LabeledField(
                label: 'Password',
                controller: _passwordController,
                hint: 'Minimum 6 characters',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                validator: (v) => (v == null || v.length < 6)
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              LabeledField(
                label: 'Confirm password',
                controller: _confirmController,
                hint: 'Re-enter your password',
                icon: Icons.lock_person_outlined,
                obscureText: _obscure,
                validator: (v) => (v != _passwordController.text)
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    activeColor: AppColors.blueDark,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppColors.blueDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.blueDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _submitting ? null : _handleSignUp,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Business Account'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                        color: AppColors.pink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
