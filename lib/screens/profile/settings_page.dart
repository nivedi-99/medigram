import 'package:flutter/material.dart';

import '../../services/theme_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool pushNotifications = true;
  bool emailNotifications = true;
  bool orderUpdatesSms = true;
  bool darkMode = false;
  bool biometricLogin = false;
  String language = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          const _SettingsHeading('Notifications'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pushNotifications,
                  onChanged: (v) => setState(() => pushNotifications = v),
                  title: const Text('Push notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Order updates, offers and reminders', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: emailNotifications,
                  onChanged: (v) => setState(() => emailNotifications = v),
                  title: const Text('Email notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Receipts and account activity', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: orderUpdatesSms,
                  onChanged: (v) => setState(() => orderUpdatesSms = v),
                  title: const Text('SMS order updates', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Delivery status via text message', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
          const _SettingsHeading('Appearance'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: AppColors.isDark,
                  onChanged: (v) => ThemeController.set(
                      v ? ThemeMode.dark : ThemeMode.light),
                  title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                      AppColors.isDark
                          ? 'Using the dark palette'
                          : 'Using the light palette',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Language', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(language, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickLanguage(context),
                ),
              ],
            ),
          ),
          const _SettingsHeading('Security'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: biometricLogin,
                  onChanged: (v) => setState(() => biometricLogin = v),
                  title: const Text('Biometric login', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Use fingerprint or Face ID to sign in', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset link sent to your email')),
                    );
                  },
                ),
              ],
            ),
          ),
          const _SettingsHeading('Account'),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('About MediGram', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Delete account',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.danger),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppColors.danger),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickLanguage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final options = ['English', 'हिन्दी', 'मराठी', 'বাংলা', 'தமிழ்'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((o) => ListTile(
                      title: Text(o),
                      trailing: language == o ? Icon(Icons.check_rounded, color: AppColors.blueDark) : null,
                      onTap: () {
                        setState(() => language = o);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete account?'),
        content: const Text('This will permanently remove your account, order history and saved details.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  final String text;
  const _SettingsHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
      ),
    );
  }
}
