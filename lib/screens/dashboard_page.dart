import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/cart_service.dart';
import 'quotation_page.dart';
import '../widgets/theme_toggle.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class DashboardPage extends StatelessWidget {
  final Customer customer;
  final String companyName;
  final List<MedicineOrder> orders;
  final int unreadNotifications;
  final VoidCallback onOpenChatbot;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final List<ProductRecord> products;

  const DashboardPage({
    super.key,
    required this.customer,
    required this.companyName,
    required this.orders,
    required this.unreadNotifications,
    required this.products,
    required this.onOpenChatbot,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  /// Distinct product categories from the live catalogue.
  List<String> get _categories {
    final seen = <String>{};
    for (final p in products) {
      if (p.category.isNotEmpty) seen.add(p.category);
    }
    return seen.toList();
  }

  /// First few live products for the featured section.
  List<ProductRecord> get _featured => products.take(4).toList();


  @override
  Widget build(BuildContext context) {
    final activeOrders =
        orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).length;
    final deliveredOrders =
        orders.where((o) => o.status == OrderStatus.delivered).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello ${customer.name}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your health, our priority',
                        style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onOpenProfile,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.blueDark,
                    child: Text(
                      customer.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const ThemeToggle(),
                _NotificationBell(
                  count: unreadNotifications,
                  onTap: onOpenNotifications,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search medicines, categories...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: AppColors.blueDark,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: IconButton(
                    onPressed: onOpenChatbot,
                    icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _companyBanner(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.local_shipping_rounded,
                    value: '$activeOrders',
                    label: 'Active orders',
                    gradient: AppColors.blueGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.verified_rounded,
                    value: '$deliveredOrders',
                    label: 'Delivered',
                    gradient: AppColors.pinkGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.account_balance_wallet_rounded,
                    value: '₹350',
                    label: 'Wallet',
                    gradient: AppColors.heroGradient,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SectionTitle(title: 'Medicine Categories'),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: AppColors.blueLight),
                  ),
                  child: Center(
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: AppColors.blueDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SectionTitle(title: 'Featured Medicine Information'),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _medicineCard(context, _featured[index]),
            childCount: _featured.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: _safetyNotice(),
          ),
        ),
      ],
    );
  }

  Widget _companyBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_pharmacy_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Trusted healthcare products, expert guidance and reliable delivery.',
                  style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicineCard(BuildContext context, ProductRecord product) {
    final initial = product.name.isEmpty
        ? '?'
        : product.name.substring(0, 1).toUpperCase();
    final hasPrice = product.price > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: SoftCard(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${product.name}...')),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 75,
              width: 75,
              decoration: BoxDecoration(
                color: AppColors.blueLight.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blueDark,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (product.description.isNotEmpty)
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        height: 1.35,
                        fontSize: 12.5,
                        color: Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    product.manufacturer.isEmpty
                        ? product.category
                        : product.manufacturer,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.blueDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        hasPrice
                            ? '\$${product.price.toStringAsFixed(2)} / unit'
                            : 'Price on request',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'MOQ ${product.minOrderQty}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            CartService.add(product);
                            // Quotation & payment hub: pay now or get a quote.
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const QuotationPage()),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded,
                              size: 16),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pink,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _safetyNotice() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB87900)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Medicine information is for educational purposes. Consult a qualified healthcare professional and upload a valid prescription before ordering prescription-only medicines.',
              style: TextStyle(color: Color(0xFF735400), height: 1.35, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(Icons.notifications_none_rounded, color: AppColors.blueDark),
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                height: 9,
                width: 9,
                decoration: BoxDecoration(
                  color: AppColors.pink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
