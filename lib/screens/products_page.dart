import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

/// Live export catalogue — sourced from the MediGram API (master list).
class ProductsPage extends StatefulWidget {
  final List<ProductRecord> products;
  final VoidCallback? onOpenCart;

  const ProductsPage({super.key, required this.products, this.onOpenCart});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String? selectedCategory;
  String _query = '';

  late final List<String> _categories = widget.products
      .map((p) => p.category)
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList();

  List<ProductRecord> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.products.where((p) {
      if (selectedCategory != null && p.category != selectedCategory) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.manufacturer.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              'Export Catalogue',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search products, manufacturers...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<int>(
                  valueListenable: CartService.count,
                  builder: (context, count, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Your order',
                        onPressed: widget.onOpenCart,
                        icon: const Icon(
                          Icons.shopping_cart_rounded,
                          color: AppColors.blueDark,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: -2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.pink,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: selectedCategory == null,
                  onTap: () => setState(() => selectedCategory = null),
                ),
                ..._categories.map(
                  (c) => _FilterChip(
                    label: c,
                    selected: selectedCategory == c,
                    onTap: () => setState(() => selectedCategory = c),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No products match your search.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ProductCard(product: items[index]),
                ),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.heroGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.blueLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.blueDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductRecord product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final initial =
        product.name.isEmpty ? '?' : product.name.substring(0, 1).toUpperCase();
    final hasPrice = product.price > 0;
    return SoftCard(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening ${product.name}...')),
        );
      },
      child: Row(
        children: [
          Container(
            height: 68,
            width: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.blueLight.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 26,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.category}  •  ${product.manufacturer.isEmpty ? 'MediGram' : product.manufacturer}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.blueDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MOQ ${product.minOrderQty}  •  ${hasPrice ? '\$${product.price.toStringAsFixed(2)} / unit' : 'Price on request'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              CartService.add(product);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} added to your order'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(
              Icons.add_circle_rounded,
              color: AppColors.pink,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
