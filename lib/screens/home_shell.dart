import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/currency_service.dart';
import '../services/database_service.dart';
import '../services/payments_service.dart';
import 'cart_page.dart';
import '../widgets/shared_widgets.dart';
import 'quotation_page.dart';
import 'dashboard_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'profile/profile_page.dart';

class HomeShell extends StatefulWidget {
  final Customer customer;
  final String country;
  final String companyName;
  final VoidCallback onLogout;

  const HomeShell({
    super.key,
    required this.customer,
    required this.country,
    required this.companyName,
    required this.onLogout,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;
  bool _loading = true;
  String? _error;

  List<MedicineOrder> _orders = [];
  List<AppNotification> _notifications = [];
  List<ProductRecord> _products = [];
  PaymentsConfig? _paymentsConfig;

  @override
  void initState() {
    super.initState();
    CurrencyService.configure(widget.country);
    CurrencyService.loadRegion();
    _loadData();
  }

  int get _unreadCount => _notifications.where((n) => n.unread).length;

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DatabaseService.fetchMyOrders(),
        DatabaseService.fetchMyNotifications(),
        DatabaseService.fetchProducts(),
      ]);
      // Payment/settlement config is optional — never block the shell on it.
      PaymentsConfig? config;
      try {
        config = await PaymentsService.fetchConfig();
        CurrencyService.setRates(config.fx);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _orders = results[0] as List<MedicineOrder>;
        _notifications = results[1] as List<AppNotification>;
        _products = results[2] as List<ProductRecord>;
        _paymentsConfig = config;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your data. Please check your connection.';
        _loading = false;
      });
    }
  }

  /// Keeps the bell count fresh when returning to data-bearing tabs.
  Future<void> _refreshNotifications() async {
    try {
      final list = await DatabaseService.fetchMyNotifications();
      if (!mounted) return;
      setState(() => _notifications = list);
    } catch (_) {
      /* silent — the stale list is still usable */
    }
  }

  /// Keeps the orders list fresh (e.g. after placing an order from the cart).
  Future<void> _refreshOrders() async {
    try {
      final list = await DatabaseService.fetchMyOrders();
      if (!mounted) return;
      setState(() => _orders = list);
    } catch (_) {
      /* silent */
    }
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CartPage(
          paymentOptions: [
            ...?_paymentsConfig?.methods
                .where((m) => m.active)
                .map((m) => m.label),
            'Letter of Credit',
            'Advance (50/50)',
          ],
          onOrderPlaced: () {
            goToTab(2);
            _refreshOrders();
          },
        ),
      ),
    );
    _refreshNotifications();
  }

  /// Keeps the catalogue fresh so products added by admins / super admins
  /// show up on the buyer Products tab right away - the live list is
  /// re-fetched every time the buyer opens the Products tab.
  Future<void> _refreshProducts() async {
    try {
      final list = await DatabaseService.fetchProducts();
      if (!mounted) return;
      setState(() => _products = list);
    } catch (_) {
      /* silent - the stale list is still usable */
    }
  }

  void goToTab(int index) {
    setState(() => selectedIndex = index);
    if (index == 0 || index == 4) _refreshNotifications();
    if (index == 1) _refreshProducts();
    if (index == 2) _refreshOrders();
  }

  // __SHELL_PART2__

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load your data',
                          message: _error!,
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ValueListenableBuilder<String>(
                    valueListenable: CurrencyService.region,
                    builder: (context, __, ___) => IndexedStack(
                      index: selectedIndex,
                      children: [
                      DashboardPage(
                        customer: widget.customer,
                        companyName: widget.companyName,
                        unreadNotifications: _unreadCount,
                        products: _products,
                        onOpenChatbot: () => goToTab(3),
                        onOpenNotifications: () => goToTab(4),
                        onOpenProfile: () => goToTab(4),
                      ),
                      ProductsPage(products: _products, onOpenCart: _openCart),
                      OrdersPage(orders: _orders),
                      const QuotationPage(),
                      ProfilePage(
                        customer: widget.customer,
                        orders: _orders,
                        notifications: _notifications,
                        paymentMethods: demoPaymentMethods,
                        onLogout: widget.onLogout,
                      ),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: _loading
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: goToTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Products',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag_rounded),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote_rounded),
                  label: 'Quotation',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
    );
  }
}

/// Payment methods remain a Phase-2 demo (no backend model yet).
final List<SavedPaymentMethod> demoPaymentMethods = [
  SavedPaymentMethod(
    label: 'HDFC Credit Card',
    detail: '•••• •••• •••• 4821',
    type: PaymentType.card,
    isDefault: true,
  ),
  SavedPaymentMethod(
    label: 'Google Pay UPI',
    detail: 'jenny@okhdfcbank',
    type: PaymentType.upi,
  ),
];
