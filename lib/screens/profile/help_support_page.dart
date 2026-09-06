import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  final faqs = const [
    {
      'q': 'How do I track my order?',
      'a': 'Go to Orders from the bottom navigation, tap any order and view '
          'the live tracking timeline inside the order details sheet.',
    },
    {
      'q': 'Can I order prescription medicines?',
      'a': 'Yes, but a valid prescription must be uploaded for restricted '
          'items before checkout can be completed.',
    },
    {
      'q': 'What payment methods are supported?',
      'a': 'Credit/debit cards, UPI, MediGram Wallet, and Cash on Delivery '
          'in select locations. Manage these in Payment Methods.',
    },
    {
      'q': 'How do I request a refund?',
      'a': 'Open the order in Orders, tap "Report issue" and choose '
          '"Billing / payment issue" — our team will follow up.',
    },
    {
      'q': 'How do I change my delivery address?',
      'a': 'Go to Profile → Edit Profile to update your saved address at '
          'any time before an order is dispatched.',
    },
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: _ContactTile(
                  icon: Icons.call_rounded,
                  label: 'Call us',
                  gradient: AppColors.blueGradient,
                  onTap: () => _snack(context, 'Calling support: 1800-123-4567'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactTile(
                  icon: Icons.chat_bubble_rounded,
                  label: 'WhatsApp',
                  gradient: AppColors.pinkGradient,
                  onTap: () => _snack(context, 'Opening WhatsApp chat...'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactTile(
                  icon: Icons.mail_rounded,
                  label: 'Email',
                  gradient: AppColors.heroGradient,
                  onTap: () => _snack(context, 'Opening email to support@medigram.app'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: faqs
                    .map(
                      (f) => ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                        title: Text(
                          f['q']!,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textDark),
                        ),
                        iconColor: AppColors.blueDark,
                        collapsedIconColor: AppColors.textMuted,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              f['a']!,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Raise a Support Ticket',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Subject',
            controller: _subjectController,
            hint: 'What do you need help with?',
            icon: Icons.subject_rounded,
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Message',
            controller: _messageController,
            hint: 'Describe your issue in detail...',
            icon: Icons.notes_rounded,
            maxLines: 5,
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: () {
              _subjectController.clear();
              _messageController.clear();
              _snack(context, 'Ticket submitted — our team will reach out within 24 hours');
            },
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Submit Ticket'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
