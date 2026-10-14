import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class EditProfilePage extends StatefulWidget {
  final Customer customer;

  const EditProfilePage({super.key, required this.customer});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer.name);
    _email = TextEditingController(text: widget.customer.email);
    _phone = TextEditingController(text: widget.customer.phone);
    _address = TextEditingController(text: widget.customer.address);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Persist to the `profiles` table in Supabase.
      await AuthService.updateProfile(
        fullName: _name.text,
        phone: _phone.text,
        country: _address.text,
      );
      widget.customer.name = _name.text.trim();
      widget.customer.phone = _phone.text.trim();
      widget.customer.address = _address.text.trim();
      if (!mounted) return;
      Navigator.of(context).pop(widget.customer);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your profile. Please try again.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.blueDark,
                    child: Text(
                      widget.customer.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        gradient: AppColors.pinkGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            LabeledField(
              label: 'Full name',
              controller: _name,
              hint: 'Your full name',
              icon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Email address (contact support to change)',
              controller: _email,
              hint: 'you@company.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Phone number',
              controller: _phone,
              hint: '+91 90000 00000',
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Delivery address',
              controller: _address,
              hint: 'House no., street, city, PIN code',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
