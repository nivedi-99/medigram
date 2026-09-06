import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

/// Dashboard shown to users with the `admin` role: manage B2B clients,
/// verify KYC, monitor orders and curate the export catalogue.
class AdminDashboardPage extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLogout;

  const AdminDashboardPage({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDashboardView(
      user: user,
      onLogout: onLogout,
      isSuperAdmin: false,
    );
  }
}

/// Dashboard shown to users with the `super_admin` role: everything an admin
/// can do, plus admin-handler management (promote / demote / deactivate).
class SuperAdminDashboardPage extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLogout;

  const SuperAdminDashboardPage({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDashboardView(
      user: user,
      onLogout: onLogout,
      isSuperAdmin: true,
    );
  }
}

class AdminDashboardView extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final bool isSuperAdmin;

  const AdminDashboardView({
    super.key,
    required this.user,
    required this.onLogout,
    required this.isSuperAdmin,
  });

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  bool _loading = true;
  String? _error;

  List<ClientRecord> _clients = [];
  List<AdminRecord> _admins = [];
  List<ProductRecord> _products = [];
  Map<String, int> _orderStats = {};
  Map<UserRole, int> _roleCounts = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DatabaseService.fetchClients(),
        DatabaseService.fetchProducts(activeOnly: false),
        DatabaseService.fetchOrderStats(),
        if (widget.isSuperAdmin) DatabaseService.fetchAdmins(),
        if (widget.isSuperAdmin) DatabaseService.fetchRoleCounts(),
      ]);

      if (!mounted) return;
      setState(() {
        _clients = results[0] as List<ClientRecord>;
        _products = results[1] as List<ProductRecord>;
        _orderStats = results[2] as Map<String, int>;
        if (widget.isSuperAdmin) {
          _admins = results[3] as List<AdminRecord>;
          _roleCounts = results[4] as Map<UserRole, int>;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load dashboard data. Check your permissions '
            'and ensure the database schema has been applied.';
        _loading = false;
      });
    }
  }

  int get _pendingCount =>
      _clients.where((c) => c.verificationStatus == 'pending').length;

  Future<void> _setVerification(ClientRecord client, String status) async {
    try {
      await DatabaseService.setClientVerification(
        clientId: client.id,
        status: status,
      );
      _toast(
        status == 'verified'
            ? '${client.companyName} verified'
            : '${client.companyName} rejected',
      );
      await _loadAll();
    } catch (_) {
      _toast('Update failed — you may lack permission.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <String>[
      'Clients',
      'Orders',
      'Products',
      if (widget.isSuperAdmin) 'Admins',
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(tabs),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load data',
                  message: _error!,
                ),
              )
            else
              Expanded(
                child: TabBarView(
                  children: [
                    _buildClientsTab(),
                    _buildOrdersTab(),
                    _buildProductsTab(),
                    if (widget.isSuperAdmin) _buildAdminsTab(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<String> tabs) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 20,
        20,
        0,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.authGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isSuperAdmin ? 'Super Admin Console' : 'Admin Console',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.user.fullName.isEmpty ? widget.user.email : widget.user.fullName} • ${widget.user.role.label}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_loading && _error == null) _buildStatTiles(),
          const SizedBox(height: 12),
          TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStatTiles() {
    final tiles = <Widget>[
      StatTile(
        icon: Icons.business_rounded,
        value: '${_clients.length}',
        label: 'B2B Clients',
        gradient: AppColors.blueGradient,
      ),
      StatTile(
        icon: Icons.hourglass_top_rounded,
        value: '$_pendingCount',
        label: 'Pending KYC',
        gradient: AppColors.pinkGradient,
      ),
      StatTile(
        icon: Icons.local_shipping_rounded,
        value: '${_orderStats['total'] ?? 0}',
        label: 'Orders',
        gradient: AppColors.blueGradient,
      ),
      StatTile(
        icon: Icons.medication_rounded,
        value: '${_products.length}',
        label: 'Products',
        gradient: AppColors.pinkGradient,
      ),
    ];
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final tile in tiles)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(width: 140, child: tile),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Clients tab — the B2B client database
  // -------------------------------------------------------------------

  Widget _buildClientsTab() {
    if (_clients.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: 'No clients registered yet',
        message: 'New B2B client registrations will appear here for review.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        itemCount: _clients.length,
        itemBuilder: (context, index) {
          final client = _clients[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ClientCard(
              client: client,
              onVerify: () => _setVerification(client, 'verified'),
              onReject: () => _setVerification(client, 'rejected'),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Orders tab
  // -------------------------------------------------------------------

  Widget _buildOrdersTab() {
    final entries = <(String, IconData, Color)>[
      ('processing', Icons.hourglass_top_rounded, AppColors.warning),
      ('shipped', Icons.local_shipping_rounded, AppColors.blueDark),
      ('delivered', Icons.check_circle_outline_rounded, AppColors.success),
      ('cancelled', Icons.cancel_outlined, AppColors.danger),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Total orders: ${_orderStats['total'] ?? 0}',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final (label, icon, color) in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 23),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${label[0].toUpperCase()}${label.substring(1)} orders',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    '${_orderStats[label] ?? 0}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Products tab
  // -------------------------------------------------------------------

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return const EmptyState(
        icon: Icons.medication_outlined,
        title: 'Catalogue is empty',
        message: 'Add products from the Supabase `products` table to '
            'populate the export catalogue.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              child: Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppColors.blueLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: AppColors.blueDark,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${product.category} • MOQ ${product.minOrderQty}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _VerificationChip(
                        status: product.isActive ? 'verified' : 'rejected',
                        labels: const {'verified': 'Active', 'rejected': 'Hidden'},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Admins tab — super admin only: the admin handler database
  // -------------------------------------------------------------------

  Widget _buildAdminsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          SoftCard(
            child: Row(
              children: [
                _RoleCountBadge(
                  label: 'Clients',
                  count: _roleCounts[UserRole.client] ?? 0,
                  icon: Icons.business_rounded,
                ),
                _RoleCountBadge(
                  label: 'Admins',
                  count: _roleCounts[UserRole.admin] ?? 0,
                  icon: Icons.support_agent_rounded,
                ),
                _RoleCountBadge(
                  label: 'Super Admins',
                  count: _roleCounts[UserRole.superAdmin] ?? 0,
                  icon: Icons.shield_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OutlinedButton.icon(
              onPressed: _showPromoteDialog,
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: const Text('Promote a user to Admin'),
            ),
          ),
          if (_admins.isEmpty)
            const EmptyState(
              icon: Icons.support_agent_outlined,
              title: 'No admin handlers',
              message: 'Promote a trusted client account to admin to let '
                  'them manage clients and orders.',
            )
          else
            for (final admin in _admins)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminCard(
                  admin: admin,
                  onToggle: () => _toggleAdmin(admin),
                  onDemote: () => _demoteAdmin(admin),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _toggleAdmin(AdminRecord admin) async {
    try {
      await DatabaseService.setAdminActive(
        adminRowId: admin.id,
        active: !admin.isActive,
      );
      _toast(admin.isActive
          ? '${admin.fullName} deactivated'
          : '${admin.fullName} reactivated');
      await _loadAll();
    } catch (_) {
      _toast('Update failed — super admin permission required.');
    }
  }

  Future<void> _demoteAdmin(AdminRecord admin) async {
    try {
      await DatabaseService.demoteAdmin(userId: admin.userId);
      _toast('${admin.fullName} demoted to client');
      await _loadAll();
    } catch (_) {
      _toast('Demotion failed — super admin permission required.');
    }
  }

  Future<void> _showPromoteDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Promote to Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the exact email of an existing account to grant '
              'admin privileges.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'user@medigram.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DatabaseService.promoteToAdmin(email: controller.text.trim());
      _toast('${controller.text.trim()} is now an admin.');
      await _loadAll();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Promotion failed — super admin permission required.');
    }
  }
}

/// Coloured chip reflecting a client's verification status.
class _VerificationChip extends StatelessWidget {
  final String status;
  final Map<String, String>? labels;

  const _VerificationChip({required this.status, this.labels});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case 'verified':
        color = AppColors.success;
      case 'rejected':
        color = AppColors.danger;
      default:
        color = AppColors.warning;
    }
    final text =
        labels?[status] ??
        (status == 'verified'
            ? 'Verified'
            : status == 'rejected'
            ? 'Rejected'
            : 'Pending');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Card representing one B2B client with verify / reject actions.
class _ClientCard extends StatelessWidget {
  final ClientRecord client;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const _ClientCard({
    required this.client,
    required this.onVerify,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.blueGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.companyName.isEmpty
                          ? 'Unnamed company'
                          : client.companyName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${client.country.isEmpty ? '—' : client.country} • ${client.contactEmail}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _VerificationChip(status: client.verificationStatus),
            ],
          ),
          if (client.businessLicenseNo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'License: ${client.businessLicenseNo}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const Divider(height: 22),
          Row(
            children: [
              TextButton.icon(
                onPressed: onVerify,
                icon: const Icon(Icons.verified_rounded, size: 17),
                label: const Text('Verify'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                ),
              ),
              TextButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.block_rounded, size: 17),
                label: const Text('Reject'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// __ADMIN_WIDGETS__

/// Card representing one admin handler with toggle / demote actions.
class _AdminCard extends StatelessWidget {
  final AdminRecord admin;
  final VoidCallback onToggle;
  final VoidCallback onDemote;

  const _AdminCard({
    required this.admin,
    required this.onToggle,
    required this.onDemote,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.pinkGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.fullName.isEmpty ? admin.email : admin.fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${admin.email} • ${admin.department}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _VerificationChip(
                status: admin.isActive ? 'verified' : 'rejected',
                labels: const {'verified': 'Active', 'rejected': 'Inactive'},
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              TextButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  admin.isActive
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 17,
                ),
                label: Text(admin.isActive ? 'Deactivate' : 'Reactivate'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.warning,
                ),
              ),
              TextButton.icon(
                onPressed: onDemote,
                icon: const Icon(Icons.person_remove_outlined, size: 17),
                label: const Text('Demote'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact stat used in the role-counts card on the Admins tab.
class _RoleCountBadge extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _RoleCountBadge({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.blueDark, size: 22),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
