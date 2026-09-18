import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/cart_service.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import 'medicine_labels_page.dart';
import 'product_detail_page.dart';

/// Live export catalogue - sourced from the MediGram API (master list).
/// Products render as cards - image placeholder, name and description - and
/// each card opens the product detail page (add to order / WhatsApp
/// quotation live there).
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
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
                      hintText: 'Search products...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Labelled medicines',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MedicineLabelsPage(products: widget.products),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.medication_rounded,
                    color: AppColors.blueDark,
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: CartService.count,
                  builder: (context, count, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Your order',
                        onPressed: widget.onOpenCart,
                        icon: Icon(
                          Icons.shopping_cart_rounded,
                          color: AppColors.blueDark,
                        ),
                      ),
                      if (count != 0)
                        Positioned(
                          right: -2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No products match your search.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 16.0;
                      final width = constraints.maxWidth;
                      final columns =
                          ((width + gap) / (316 + gap)).floor().clamp(1, 4);
                      final cardWidth =
                          (width - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final p in items)
                            SizedBox(
                              width: cardWidth,
                              height: 310,
                              child: _ProductCard(product: p),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Responsive uniform grid; every card is a fixed-size box so the hover
  /// glow cards can never overflow, on any screen width.
}

/// Maps a medicine name to its generated image slug:
/// 'Pregabalin 300mg' -> 'pregabalin-300mg'. Must stay in sync with
/// tool/generate_label_images.dart, which writes the files.
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// One catalogue product card: image placeholder on the left, the item name,
/// description and price on the right. Tapping opens the product detail
/// page.
class _ProductCard extends StatefulWidget {
  final ProductRecord product;

  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hover = false;

  ProductRecord get product => widget.product;

  String get _generic =>
      product.manufacturer.isEmpty ? 'General' : product.manufacturer;

  /// Catalogue description, pipe-normalised for card display. Falls back to
  /// category/manufacturer so the card never looks empty.
  String get _description {
    final text = product.description
        .split('|')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' - ');
    if (text.isNotEmpty) return text;
    final bits = <String>[
      if (product.category.isNotEmpty) product.category,
      if (product.manufacturer.isNotEmpty) product.manufacturer,
    ];
    return bits.isEmpty ? 'No description provided.' : bits.join(' - ');
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? AppColors.blueMid : AppColors.border,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.shadow.withValues(alpha: _hover ? 0.08 : 0.05),
                blurRadius: _hover ? 14 : 10,
                offset: Offset(0, _hover ? 6 : 4),
              ),
              if (_hover)
                BoxShadow(
                  color: AppColors.blueMid.withValues(alpha: 0.30),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductDetailPage(product: product),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ImageTile(product: product),
                      const Spacer(),
                      _CardBadge(product.category.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Generic: $_generic',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _DashedDivider(),
                  const SizedBox(height: 8),
                  Text(
                    _description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        CurrencyService.format(product.price),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blueDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ unit',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProductDetailPage(product: product),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blueDark,
                        foregroundColor: AppColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('View details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded image tile at the top-left of a catalogue card: shows the
/// generated labelled bottle shot for this medicine, or a soft placeholder
/// tile with a medication icon.
class _ImageTile extends StatelessWidget {
  final ProductRecord product;

  const _ImageTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.network(
          'assets/products/labels/${_slug(product.name)}.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.blueLight.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: Icon(
              Icons.medication_rounded,
              size: 26,
              color: AppColors.blueMid.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// Amber pill badge (category), like the GLOBAL badge on the framed cards.
class _CardBadge extends StatelessWidget {
  final String text;

  const _CardBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

/// Thin dashed rule used inside catalogue cards.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dash = 6.0;
          const gap = 5.0;
          final count =
              (constraints.maxWidth / (dash + gap)).floor().clamp(1, 200);
          return Row(
            children: List.generate(
              count,
              (i) => Container(
                width: dash,
                height: 1,
                margin: EdgeInsets.only(right: i == count - 1 ? 0 : gap),
                color: AppColors.textMuted.withValues(alpha: 0.45),
              ),
            ),
          );
        },
      ),
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