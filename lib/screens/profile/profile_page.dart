import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import '../payment/payment_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import 'notifications_page.dart';
import 'help_support_page.dart';

class ProfilePage extends StatefulWidget {
  final Customer customer;
  final List<MedicineOrder> orders;
  final List<AppNotification> notifications;
  final List<SavedPaymentMethod> paymentMethods;
  final VoidCallback onLogout;
  final VoidCallback? onDataChanged;

  const ProfilePage({
    super.key,
    required this.customer,
    required this.orders,
    required this.notifications,
    required this.paymentMethods,
    required this.onLogout,
    this.onDataChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Customer customer;

  @override
  void initState() {
    super.initState();
    customer = widget.customer;
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.notifications.where((n) => n.unread).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.blueDark,
              child: Text(
                customer.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.email,
                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pinkLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Verified Customer',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.pink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                final updated = await Navigator.of(context).push<Customer>(
                  MaterialPageRoute(
                    builder: (_) => EditProfilePage(customer: customer),
                  ),
                );
                if (updated != null) setState(() => customer = updated);
              },
              icon: Icon(Icons.edit_outlined, color: AppColors.blueDark),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SoftCard(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              _InfoRow(icon: Icons.call_outlined, label: 'Phone', value: customer.phone.isEmpty ? 'Not set' : customer.phone),
              const Divider(height: 1, indent: 54),
              _InfoRow(icon: Icons.location_on_outlined, label: 'Address', value: customer.address.isEmpty ? 'Not set' : customer.address),
              const Divider(height: 1, indent: 54),
              _InfoRow(icon: Icons.calendar_today_outlined, label: 'Member since', value: _formatDate(customer.joinedOn)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _StatBadge(value: '${widget.orders.length}', label: 'Orders')),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBadge(
                value: '${widget.orders.where((o) => o.status == OrderStatus.delivered).length}',
                label: 'Delivered',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: _StatBadge(value: '₹350', label: 'Wallet')),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 15),
        ),
        const SizedBox(height: 6),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            children: [
              MenuTile(
                icon: Icons.credit_card_rounded,
                title: 'Payment Methods',
                subtitle: '${widget.paymentMethods.length} saved methods',
                iconColor: AppColors.pink,
                iconBg: AppColors.pinkLight,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PaymentPage(methods: widget.paymentMethods),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: unread > 0 ? '$unread unread' : 'All caught up',
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(builder: (_) => const NotificationsPage()),
                      )
                      .then((_) => widget.onDataChanged?.call());
                },
              ),
              const Divider(height: 1),
              MenuTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Preferences, security, language',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const Divider(height: 1),
              MenuTile(
                icon: Icons.support_agent_rounded,
                title: 'Help & Support',
                subtitle: 'FAQs, contact us, raise a ticket',
                iconColor: AppColors.pink,
                iconBg: AppColors.pinkLight,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: MenuTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            iconColor: AppColors.danger,
            iconBg: const Color(0xFFFFE3E3),
            trailing: const SizedBox.shrink(),
            onTap: () => _confirmLogout(context),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'MediGram v1.0.0',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to place orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onLogout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.blueDark),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;

  const _StatBadge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textDark),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
