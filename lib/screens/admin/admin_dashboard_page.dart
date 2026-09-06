import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/currency_service.dart';
import '../../services/database_service.dart';
import '../../services/payments_service.dart';
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
      'Payments',
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
                    _buildPaymentsTab(),
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
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            ),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.medication_outlined,
              title: 'Catalogue is empty',
              message: 'Use "Add product" to create the first listing.',
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_products.length} catalogue entries — tap one to edit',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blueDark,
                  foregroundColor: AppColors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SoftCard(
                    onTap: () => _showProductEditDialog(product),
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
                              CurrencyService.format(product.price),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _VerificationChip(
                              status:
                                  product.isActive ? 'verified' : 'rejected',
                              labels: const {
                                'verified': 'Active',
                                'rejected': 'Hidden'
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  // -------------------------------------------------------------------
  // Payments tab — WhatsApp number, FX rates, settlement channels
  // -------------------------------------------------------------------

  PaymentsConfig? _payments;
  bool _paymentsLoading = false;

  Future<void> _ensurePayments() async {
    if (_payments != null || _paymentsLoading) return;
    setState(() => _paymentsLoading = true);
    try {
      final config = await PaymentsService.fetchConfig();
      if (!mounted) return;
      setState(() {
        _payments = config;
        _paymentsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _paymentsLoading = false;
      });
    }
  }

  Widget _buildPaymentsTab() {
    if (_payments == null) {
      _ensurePayments();
      return const Center(child: CircularProgressIndicator());
    }
    final cfg = _payments!;
    return RefreshIndicator(
      onRefresh: () async {
        _payments = null;
        await _ensurePayments();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          Text(
            'Settlement channels',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Channels clients use to remit globally to your Indian account. '
            'Details are placeholders — replace with real receiving details.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          ...cfg.methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                onTap: () => _showChannelEditDialog(m),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    m.active
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    size: 30,
                    color: m.active ? AppColors.success : AppColors.textMuted,
                  ),
                  title: Text(m.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.textDark)),
                  subtitle: Text(
                      '${m.details.length} detail field(s) • tap to edit',
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
            ),
          ),
          const Divider(height: 30),
          Text(
            'FX rates (units per 1 USD)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cfg.fx.entries
                .map((e) => Chip(
                      label: Text(
                          '${e.key} ${e.value < 0.01 ? e.value.toStringAsFixed(8) : e.value.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textDark)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showFxEditDialog,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit FX rates'),
          ),
          const Divider(height: 30),
          Text(
            'WhatsApp business number',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showWhatsAppEditDialog,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(cfg.whatsappNumber),
          ),
        ],
      ),
    );
  }
  Future<void> _savePayments(PaymentsConfig config) async {
    await PaymentsService.saveConfig(config);
    if (!mounted) return;
    setState(() => _payments = config);
    CurrencyService.setRates(config.fx);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment settings saved')),
    );
  }

  void _showChannelEditDialog(PaymentChannel channel) {
    final label = TextEditingController(text: channel.label);
    final instructions = TextEditingController(text: channel.instructions);
    final details = TextEditingController(
      text: channel.details.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    );
    var active = channel.active;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit ${channel.key}', style: const TextStyle(fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: label, decoration: const InputDecoration(hintText: 'Label')),
                const SizedBox(height: 10),
                TextField(controller: instructions, maxLines: 3, decoration: const InputDecoration(hintText: 'Instructions')),
                const SizedBox(height: 10),
                TextField(
                    controller: details,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        hintText: 'Details, one per line:\nBeneficiary: Name\nAccount No: 0000')),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final detailsMap = <String, String>{};
                for (final line in details.text.split('\n')) {
                  final idx = line.indexOf(':');
                  if (idx > 0) {
                    detailsMap[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
                  }
                }
                final methods = _payments!.methods
                    .map((m) => m.key == channel.key
                        ? PaymentChannel(
                            key: m.key,
                            label: label.text.trim(),
                            tagline: m.tagline,
                            details: detailsMap,
                            instructions: instructions.text.trim(),
                            sortOrder: m.sortOrder,
                            active: active,
                          )
                        : m)
                    .toList();
                Navigator.pop(dialogContext);
                await _savePayments(PaymentsConfig(
                    whatsappNumber: _payments!.whatsappNumber,
                    fx: _payments!.fx,
                    methods: methods));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  void _showFxEditDialog() {
    final controllers = <String, TextEditingController>{
      for (final e in _payments!.fx.entries)
        e.key: TextEditingController(
            text: e.value < 0.01
                ? e.value.toStringAsFixed(8)
                : e.value.toStringAsFixed(4)),
    };
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit FX rates', style: TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: e.value,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            InputDecoration(hintText: '${e.key} per 1 USD'),
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final fx = <String, double>{};
              controllers.forEach((key, c) {
                final v = double.tryParse(c.text.trim());
                if (v != null && v > 0) fx[key] = v;
              });
              Navigator.pop(dialogContext);
              await _savePayments(PaymentsConfig(
                  whatsappNumber: _payments!.whatsappNumber,
                  fx: fx,
                  methods: _payments!.methods));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppEditDialog() {
    final controller = TextEditingController(text: _payments!.whatsappNumber);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('WhatsApp number', style: TextStyle(fontSize: 17)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: '+91 90000 00000'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _savePayments(PaymentsConfig(
                  whatsappNumber: controller.text.trim(),
                  fx: _payments!.fx,
                  methods: _payments!.methods));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  void _showProductEditDialog(ProductRecord product) {
    final price = TextEditingController(text: product.price.toStringAsFixed(2));
    final moq = TextEditingController(text: product.minOrderQty.toString());
    final category = TextEditingController(text: product.category);
    final manufacturer = TextEditingController(text: product.manufacturer);
    final description = TextEditingController(text: product.description);
    var isActive = product.isActive;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit ${product.name}', style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        hintText: 'Price (USD)', labelText: 'Price (USD)')),
                const SizedBox(height: 10),
                TextField(
                    controller: moq,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        hintText: 'Minimum order qty',
                        labelText: 'Minimum order qty')),
                const SizedBox(height: 10),
                TextField(
                    controller: category,
                    decoration: const InputDecoration(
                        hintText: 'Category', labelText: 'Category')),
                const SizedBox(height: 10),
                TextField(
                    controller: manufacturer,
                    decoration: const InputDecoration(
                        hintText: 'Manufacturer', labelText: 'Manufacturer')),
                const SizedBox(height: 10),
                TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Description', labelText: 'Description')),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  title: const Text('Active in catalogue'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final updated = await DatabaseService.updateProduct(
                  id: product.id,
                  category: category.text.trim(),
                  manufacturer: manufacturer.text.trim(),
                  description: description.text.trim(),
                  price: double.tryParse(price.text.trim()) ?? product.price,
                  minOrderQty: int.tryParse(moq.text.trim()) ?? product.minOrderQty,
                  isActive: isActive,
                );
                if (!mounted) return;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (!mounted) return;
                setState(() {
                  _products[_products.indexWhere((p) => p.id == product.id)] =
                      updated;
                });
                messenger.showSnackBar(
                  SnackBar(content: Text('${updated.name} updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  void _showAddProductDialog() {
    final name = TextEditingController();
    final price = TextEditingController();
    final moq = TextEditingController(text: '100');
    final category = TextEditingController();
    final manufacturer = TextEditingController();
    final form = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add product', style: TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: name,
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Name required' : null,
                    decoration: const InputDecoration(
                        hintText: 'Product name', labelText: 'Product name')),
                const SizedBox(height: 10),
                TextFormField(
                    controller: category,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Category required' : null,
                    decoration: const InputDecoration(
                        hintText: 'Category', labelText: 'Category')),
                const SizedBox(height: 10),
                TextFormField(
                    controller: manufacturer,
                    decoration: const InputDecoration(
                        hintText: 'Manufacturer (optional)',
                        labelText: 'Manufacturer')),
                const SizedBox(height: 10),
                TextFormField(
                    controller: price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => double.tryParse(v ?? '') == null
                        ? 'Valid price required'
                        : null,
                    decoration: const InputDecoration(
                        hintText: 'Price in USD', labelText: 'Price (USD)')),
                const SizedBox(height: 10),
                TextFormField(
                    controller: moq,
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v ?? '') == null
                        ? 'Valid MOQ required'
                        : null,
                    decoration: const InputDecoration(
                        hintText: 'Minimum order qty',
                        labelText: 'Minimum order qty')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              final created = await DatabaseService.createProduct(
                name: name.text.trim(),
                category: category.text.trim(),
                manufacturer: manufacturer.text.trim(),
                price: double.parse(price.text.trim()),
                minOrderQty: int.parse(moq.text.trim()),
              );
              if (!mounted) return;
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              setState(() => _products.insert(0, created));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${created.name} added to catalogue')),
              );
            },
            child: const Text('Create'),
          ),
        ],
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
