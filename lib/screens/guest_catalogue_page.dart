import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import 'products_page.dart';

/// Public catalogue for signed-out visitors — opened by every "Browse
/// Medicines" / category entry on the landing page. Loads the live export
/// catalogue anonymously (GET /products is public) and renders the same
/// catalogue cards signed-in buyers see. Ordering prompts the visitor to
/// create an account instead of breaking at checkout.
class GuestCataloguePage extends StatefulWidget {
  /// Opens the login page on the root navigator; completes when it closes.
  final Future<void> Function() onLogin;

  const GuestCataloguePage({super.key, required this.onLogin});

  @override
  State<GuestCataloguePage> createState() => _GuestCataloguePageState();
}

class _GuestCataloguePageState extends State<GuestCataloguePage> {
  bool _loading = true;
  String? _error;
  List<ProductRecord> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await DatabaseService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
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
        _error = 'Could not load the catalogue. Please check your connection.';
        _loading = false;
      });
    }
  }

  /// Pull-to-refresh: re-fetches the catalogue without the full-screen
  /// spinner so the page keeps its content while updating.
  Future<void> _refresh() async {
    try {
      final products = await DatabaseService.fetchProducts();
      if (!mounted) return;
      setState(() => _products = products);
    } catch (_) {
      /* silent — keep the current catalogue */
    }
  }

  /// Opens login; when the visitor signs in, the root home swaps to their
  /// portal, so this page pops itself out of the way.
  Future<void> _openLogin() async {
    await widget.onLogin();
    if (!mounted) return;
    if (ApiClient.hasSession && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _promptLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create a free account to start an order.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _openLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load the catalogue',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : ProductsPage(
                          products: _products,
                          guestMode: true,
                          onRequiresLogin: _promptLogin,
                          onRefresh: _refresh,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          ),
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              gradient: AppColors.blueGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_pharmacy_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Catalogue',
                  style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark),
                ),
                Text(
                  'Browsing as a guest - sign in to order',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueDark,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Login',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
