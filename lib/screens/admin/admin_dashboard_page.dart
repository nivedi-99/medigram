import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/currency_service.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/payments_service.dart';
import '../../services/product_image.dart';
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
  List<MedicineOrder> _orders = [];
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
        DatabaseService.fetchAllOrders(),
        if (widget.isSuperAdmin) DatabaseService.fetchAdmins(),
        if (widget.isSuperAdmin) DatabaseService.fetchRoleCounts(),
      ]);

      if (!mounted) return;
      setState(() {
        _clients = results[0] as List<ClientRecord>;
        // Deleted (soft-hidden) products stay out of the admin list — the
        // API returns inactive rows to admins, so filter them here.
        _products = (results[1] as List<ProductRecord>)
            .where((p) => p.isActive)
            .toList();
        _orderStats = results[2] as Map<String, int>;
        _orders = results[3] as List<MedicineOrder>;
        if (widget.isSuperAdmin) {
          _admins = results[4] as List<AdminRecord>;
          _roleCounts = results[5] as Map<UserRole, int>;
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
      if (widget.isSuperAdmin) 'Exports',
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        // '+' product symbol - shown while the Products tab is open, so
        // admins and super admins can publish a listing that buyers
        // immediately see when they open their own Products tab.
        floatingActionButton: Builder(
          builder: (fabContext) {
            final tabController = DefaultTabController.of(fabContext);
            return AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                final onProductsTab = tabController.index == 2;
                return AnimatedScale(
                  scale: onProductsTab ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: FloatingActionButton.extended(
                    heroTag: 'admin-add-product-fab',
                    onPressed: onProductsTab ? _showAddProductDialog : null,
                    backgroundColor: AppColors.blueDark,
                    foregroundColor: AppColors.onPrimary,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add product'),
                  ),
                );
              },
            );
          },
        ),
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
                    if (widget.isSuperAdmin) _buildExportsTab(),
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
                      widget.isSuperAdmin
                          ? 'Super Admin Console'
                          : 'Admin Console',
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
        const SizedBox(height: 8),
        Text(
          'Recent orders - mark payments and download invoices',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        if (_orders.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            message: 'Client export orders will appear here.',
          )
        else
          for (final order in _orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminOrderCard(
                order: order,
                onTogglePaid: () => _togglePayment(order),
                onInvoice: () => _downloadInvoice(order),
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
      // Adding happens through the floating "+ Add product" button (bottom
      // right) — the single entry point for publishing a listing.
      return const Column(
        children: [
          Expanded(
            child: EmptyState(
              icon: Icons.medication_outlined,
              title: 'Catalogue is empty',
              message:
                  'Use the "+ Add product" button to create the first listing.',
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
                          child: product.hasPhoto
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    product.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                      Icons.medication_rounded,
                                      color: AppColors.blueDark,
                                      size: 23,
                                    ),
                                  ),
                                )
                              : Icon(
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
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Delete product',
                          onPressed: () => _confirmDeleteProduct(product),
                          icon: Icon(Icons.delete_outline_rounded,
                              color: AppColors.danger),
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
      text:
          channel.details.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
    );
    var active = channel.active;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title:
              Text('Edit ${channel.key}', style: const TextStyle(fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: label,
                    decoration: const InputDecoration(hintText: 'Label')),
                const SizedBox(height: 10),
                TextField(
                    controller: instructions,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(hintText: 'Instructions')),
                const SizedBox(height: 10),
                TextField(
                    controller: details,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        hintText:
                            'Details, one per line:\nBeneficiary: Name\nAccount No: 0000')),
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
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final detailsMap = <String, String>{};
                for (final line in details.text.split('\n')) {
                  final idx = line.indexOf(':');
                  if (idx > 0) {
                    detailsMap[line.substring(0, idx).trim()] =
                        line.substring(idx + 1).trim();
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
    final strength = TextEditingController(text: product.strength);
    var isActive = product.isActive;
    PickedImage? newImage;
    var removeImage = false;
    var saving = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit ${product.name}',
              style: const TextStyle(fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProductImageField(
                  picked: newImage,
                  existingUrl: removeImage ? '' : product.imageUrl,
                  hasStoredPhoto: product.hasStoredPhoto,
                  onPick: () async {
                    try {
                      final image = await pickProductImage();
                      if (image != null && dialogContext.mounted) {
                        setDialogState(() {
                          newImage = image;
                          removeImage = false;
                        });
                      }
                    } catch (e) {
                      _toast('Could not add the image: $e');
                    }
                  },
                  onRemove: () {
                    // Wrong image? Drop the pending pick, or mark the stored
                    // photo for removal ( buyers then see the category shot).
                    if (newImage != null) {
                      setDialogState(() => newImage = null);
                    } else {
                      setDialogState(() => removeImage = true);
                    }
                  },
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                TextField(
                    controller: strength,
                    decoration: const InputDecoration(
                        hintText: 'e.g. 500 mg', labelText: 'Strength')),
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
              onPressed: saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setDialogState(() => saving = true);
                      try {
                        var updated = await DatabaseService.updateProduct(
                          id: product.id,
                          category: category.text.trim(),
                          manufacturer: manufacturer.text.trim(),
                          description: description.text.trim(),
                          strength: strength.text.trim(),
                          price: double.tryParse(price.text.trim()) ??
                              product.price,
                          minOrderQty: int.tryParse(moq.text.trim()) ??
                              product.minOrderQty,
                          isActive: isActive,
                        );
                        // Photo changes: swap in a new upload, or clear the
                        // stored photo when the admin removed it.
                        final image = newImage;
                        final oldUrl = product.imageUrl;
                        if (image != null) {
                          try {
                            final url =
                                await DatabaseService.uploadProductImage(image,
                                    productId: product.id);
                            updated = await DatabaseService.updateProduct(
                                id: product.id, imageUrl: url);
                            // Only clean up the previous object when the
                            // photo now lives somewhere else.
                            if (oldUrl.isNotEmpty && oldUrl != url) {
                              DatabaseService.deleteProductImage(oldUrl);
                            }
                            if (!updated.hasStoredPhoto) {
                              messenger.showSnackBar(const SnackBar(
                                content: Text('Photo attached and live for '
                                    'buyers. Tip: apply '
                                    'supabase/add_product_images.sql to also '
                                    'record it in the database'),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Saved, but the new image could not be uploaded: $e')));
                          }
                        } else if (removeImage && oldUrl.isNotEmpty) {
                          updated = await DatabaseService.updateProduct(
                              id: product.id, imageUrl: '');
                          DatabaseService.deleteProductImage(oldUrl);
                        }
                        if (!mounted) return;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (!mounted) return;
                        setState(() {
                          _products[_products
                              .indexWhere((p) => p.id == product.id)] = updated;
                        });
                        messenger.showSnackBar(
                          SnackBar(content: Text('${updated.name} updated')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Update failed: $e')),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2))
                  : const Text('Save'),
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
    final strength = TextEditingController();
    final description = TextEditingController();
    final form = GlobalKey<FormState>();
    PickedImage? pickedImage;
    var saving = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add product', style: TextStyle(fontSize: 17)),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProductImageField(
                    picked: pickedImage,
                    existingUrl: '',
                    hasStoredPhoto: false,
                    onPick: () async {
                      try {
                        final image = await pickProductImage();
                        if (image != null && dialogContext.mounted) {
                          setDialogState(() => pickedImage = image);
                        }
                      } catch (e) {
                        _toast('Could not add the image: $e');
                      }
                    },
                    onRemove: () => setDialogState(() => pickedImage = null),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: name,
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Name required'
                          : null,
                      decoration: const InputDecoration(
                          hintText: 'Product name', labelText: 'Product name')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: category,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Category required'
                          : null,
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
                      controller: strength,
                      decoration: const InputDecoration(
                          hintText: 'e.g. 500 mg', labelText: 'Strength')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          hintText: 'Shown on the product card',
                          labelText: 'Description')),
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
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        var created = await DatabaseService.createProduct(
                          name: name.text.trim(),
                          category: category.text.trim(),
                          manufacturer: manufacturer.text.trim(),
                          description: description.text.trim(),
                          strength: strength.text.trim(),
                          price: double.parse(price.text.trim()),
                          minOrderQty: int.parse(moq.text.trim()),
                        );
                        // Attach the picked photo; an upload failure must
                        // never block the product from being created.
                        final image = pickedImage;
                        if (image != null) {
                          try {
                            final url =
                                await DatabaseService.uploadProductImage(image,
                                    productId: created.id);
                            created = await DatabaseService.updateProduct(
                                id: created.id, imageUrl: url);
                            if (!created.hasStoredPhoto) {
                              _toast('Photo attached and live for buyers. Tip: '
                                  'apply supabase/add_product_images.sql to '
                                  'also record it in the database');
                            }
                          } catch (e) {
                            if (!mounted) return;
                            _toast('${created.name} was created, but the '
                                'image could not be uploaded: $e');
                          }
                        }
                        if (!mounted) return;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        setState(() => _products.insert(0, created));
                        _toast(
                            '${created.name} added to catalogue - it appears in '
                            'the buyer Products tab automatically');
                      } catch (e) {
                        if (!mounted) return;
                        _toast('Could not add the product: $e');
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Exports tab - super admin only: CSV downloads via the MediGram API
  // -------------------------------------------------------------------

  Widget _buildExportsTab() {
    final items = <(String, IconData, String, Future<String> Function())>[
      (
        'Products CSV',
        Icons.medication_rounded,
        'Full catalogue incl. hidden entries, prices, MOQ and strength.',
        ExportService.productsCsv,
      ),
      (
        'Users CSV',
        Icons.people_alt_rounded,
        'Every registered user with role, company, country and KYC status.',
        ExportService.usersCsv,
      ),
      (
        'Payments / orders CSV',
        Icons.receipt_long_rounded,
        'All orders with payment method, payment status and totals.',
        ExportService.ordersCsv,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        Text(
          'Data exports (CSV)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Live data pulled from the database through the MediGram API and '
          'downloaded as a CSV file.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        for (final (label, icon, note, fetch) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: AppColors.blueDark, size: 23),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            note,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final where = await fetch();
                          _toast('Downloaded: $where');
                        } catch (_) {
                          _toast('Download failed - check your connection.');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blueDark,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Tip: invoices for individual orders live in the Orders tab - '
          'tap Invoice on any order row.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
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

  Future<void> _togglePayment(MedicineOrder order) async {
    final paid = order.paymentStatus == 'paid';
    try {
      await DatabaseService.setOrderPaymentStatus(
          orderId: order.uuid, paid: !paid);
      _toast('${order.id} marked ${paid ? 'pending' : 'paid'}');
      await _loadAll();
    } catch (_) {
      _toast('Could not update payment status - run the database upgrade '
          'script (upgrade_strength_payments.sql) first.');
    }
  }

  Future<void> _downloadInvoice(MedicineOrder order) async {
    try {
      await ExportService.invoiceCsv(order.uuid);
      _toast('Invoice for ${order.id} downloaded');
    } catch (_) {
      _toast('Invoice download failed - check your connection.');
    }
  }

  /// Asks for confirmation, then soft-deletes the product (hidden from
  /// buyers; order history is preserved server-side).
  Future<void> _confirmDeleteProduct(ProductRecord product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete product', style: TextStyle(fontSize: 17)),
        content: Text(
          'Hide "${product.name}" from the catalogue? Buyers will no longer '
          'see it. Past orders are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await DatabaseService.deleteProduct(id: product.id);
      if (!mounted) return;
      // Remove it from the list right away so the deletion is visible
      // without waiting for a reload (the API soft-deletes the row; buyers
      // and this list no longer show it).
      setState(() => _products.removeWhere((p) => p.id == product.id));
      _toast('${product.name} deleted - removed from the catalogue');
    } catch (e) {
      if (!mounted) return;
      _toast('Could not delete the product: $e');
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
    final text = labels?[status] ??
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

/// One order row in the admin Orders tab: client, total, payment chip and
/// actions (mark paid / download invoice).
class _AdminOrderCard extends StatelessWidget {
  final MedicineOrder order;
  final VoidCallback onTogglePaid;
  final VoidCallback onInvoice;

  const _AdminOrderCard({
    required this.order,
    required this.onTogglePaid,
    required this.onInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final paid = order.paymentStatus == 'paid';
    final chipColor = paid ? AppColors.success : AppColors.warning;
    return SoftCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.id}  |  ${order.date.toIso8601String().substring(0, 10)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: chipColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    paid ? 'Paid' : 'Payment pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: chipColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.clientEmail.isEmpty
                  ? '${order.items.length} item(s) | ${order.paymentMethod}'
                  : '${order.clientEmail} | ${order.items.length} item(s) | ${order.paymentMethod}',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  CurrencyService.format(order.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.blueDark,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onTogglePaid,
                  icon: Icon(
                    paid ? Icons.money_off_rounded : Icons.payments_rounded,
                    size: 16,
                  ),
                  label: Text(paid ? 'Mark unpaid' : 'Mark paid'),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed: onInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueDark,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Invoice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Image section for the Add/Edit product dialogs: a preview of the picked
/// (or stored) photo, an "Add image" button that opens the browser file
/// picker (local files or Google Drive), and a Remove button so a wrong
/// image can be deleted before saving.
class _ProductImageField extends StatelessWidget {
  final PickedImage? picked;
  final String existingUrl;
  final bool hasStoredPhoto;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ProductImageField({
    required this.picked,
    required this.existingUrl,
    required this.hasStoredPhoto,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasStoredImage =>
      picked == null && hasStoredPhoto && existingUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // A photo counts as "present" when one was just picked, is recorded in
    // the database, or the canonical storage URL resolves (photo uploaded
    // while the image_url column is not applied yet).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product photo',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        if (picked != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.memory(picked!.bytes,
                  fit: BoxFit.cover, key: ValueKey(picked!.filename)),
            ),
          )
        else if (existingUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.network(
                existingUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _emptyPreview(),
              ),
            ),
          )
        else
          _emptyPreview(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: Icon(_hasStoredImage || picked != null
                    ? Icons.swap_horiz_rounded
                    : Icons.upload_rounded),
                label: Text(_hasStoredImage || picked != null
                    ? 'Replace image'
                    : 'Add image'),
              ),
            ),
            if (_hasStoredImage || picked != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove image',
                onPressed: onRemove,
                icon:
                    Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              ),
            ],
          ],
        ),
        if (picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${picked!.filename} (${picked!.sizeLabel})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  /// Dashed placeholder shown when the product has no photo (the canonical
  /// URL 404s for products that were never given one).
  Widget _emptyPreview() {
    return Container(
      height: 110,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blueLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.blueLight, width: 1.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_rounded,
              size: 30, color: AppColors.blueMid),
          const SizedBox(height: 6),
          Text(
            'No image yet - buyers see the category shot',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
