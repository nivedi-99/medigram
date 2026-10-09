import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import 'product_detail_page.dart';

/// Labelled medicine showcase — pharmaexport-style framed medicine cards.
///
/// Purely additive: a read-only view over the same [ProductRecord] list the
/// Export Catalogue loads. Cards mirror the pharmaexport design (image tile,
/// badge, name, generic line, dashed rule, spec table, big price and a
/// full-width button) and glow on their borders + lift slightly on hover.
/// Placeholder cards (sample medicines) fill the page while the live
/// catalogue is empty.
class MedicineLabelsPage extends StatelessWidget {
  final List<ProductRecord> products;

  const MedicineLabelsPage({super.key, required this.products});

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
              child: products.isEmpty
                  ? _buildSampleCatalogue()
                  : _buildGrid(
                      products
                          .map((p) => _CardItem(p, null, products))
                          .toList(),
                      samples: false,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 20, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to catalogue',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Labelled medicines',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              products.isEmpty
                  ? 'Sample showcase'
                  : '${products.length} medicine${products.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.blueDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder showcase: sample medicines (values from the pharmaexport
  /// source catalogue) rendered as the same framed cards while the live
  /// catalogue is empty.
  Widget _buildSampleCatalogue() {
    final records = _placeholderMedicines
        .map((m) => ProductRecord(
              id: 'sample-${m.name}',
              name: m.name,
              category: m.category,
              manufacturer: m.manufacturer,
              price: m.price,
              minOrderQty: m.moq,
            ))
        .toList();
    final items = <_CardItem>[
      for (var i = 0; i < records.length; i++)
        _CardItem(records[i], _placeholderMedicines[i].packing, records),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Text(
            'Placeholder cards - sample medicines shown until the live '
            'catalogue loads.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(child: _buildGrid(items, samples: true)),
      ],
    );
  }

  /// Responsive uniform grid; every card is a fixed-size box so the hover
  /// glow cards can never overflow, on any screen width.
  Widget _buildGrid(List<_CardItem> items, {required bool samples}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 16.0;
            final width = constraints.maxWidth;
            final columns = ((width + gap) / (316 + gap)).floor().clamp(1, 4);
            final cardWidth = (width - gap * (columns - 1)) / columns;
            return SingleChildScrollView(
              child: Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: cardWidth,
                      height: 318,
                      child: _MedicineLabelCard(
                        product: item.product,
                        packing: item.packing,
                        catalogue: item.catalogue ?? const [],
                        isPlaceholder: samples,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One catalogue item for the grid: the record plus an optional packing
/// string (sample medicines carry '1 x 10' from the pharmaexport source)
/// and the catalogue passed on to the detail page's similar-products side
/// bar.
class _CardItem {
  final ProductRecord product;
  final String? packing;
  final List<ProductRecord>? catalogue;
  const _CardItem(this.product, [this.packing, this.catalogue]);
}

/// Maps a medicine name to its generated image slug:
/// 'Pregabalin 300mg' -> 'pregabalin-300mg'. Must stay in sync with
/// tool/generate_label_images.dart, which writes the files.
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// One framed medicine card (pharmaexport style): image tile + badge,
/// name + generic line, dashed rule, spec table, big price and a
/// full-width button. Glows on its borders and lifts slightly on hover.
class _MedicineLabelCard extends StatefulWidget {
  final ProductRecord product;
  final String? packing;

  /// Catalogue for the detail page's similar-products side bar.
  final List<ProductRecord> catalogue;
  final bool isPlaceholder;

  const _MedicineLabelCard({
    required this.product,
    this.packing,
    this.catalogue = const [],
    this.isPlaceholder = false,
  });

  @override
  State<_MedicineLabelCard> createState() => _MedicineLabelCardState();
}

class _MedicineLabelCardState extends State<_MedicineLabelCard> {
  bool _hover = false;

  ProductRecord get product => widget.product;
  bool get isPlaceholder => widget.isPlaceholder;

  String get _generic =>
      product.manufacturer.isEmpty ? 'General' : product.manufacturer;

  String get _packingLabel => widget.packing != null ? 'Packing' : 'Min. order';

  String get _packingValue =>
      widget.packing ??
      '${product.minOrderQty} unit${product.minOrderQty == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover ? AppColors.blueMid : AppColors.border,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: _hover ? 0.08 : 0.05),
                blurRadius: _hover ? 16 : 10,
                offset: Offset(0, _hover ? 8 : 4),
              ),
              if (_hover)
                BoxShadow(
                  color: AppColors.blueMid.withValues(alpha: 0.32),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isPlaceholder
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailPage(
                          product: product,
                          catalogue: widget.catalogue,
                        ),
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
                      _Badge(isPlaceholder
                          ? 'SAMPLE'
                          : product.category.toUpperCase()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.15,
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
                  const SizedBox(height: 10),
                  const _DashedDivider(),
                  const SizedBox(height: 10),
                  _specRow(_packingLabel, _packingValue),
                  _specRow(
                      'Manufacturer',
                      product.manufacturer.isEmpty
                          ? '-'
                          : product.manufacturer),
                  _specRow('Category', product.category),
                  const Spacer(),
                  // --- Big price, teal, like the framed HTML card ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        CurrencyService.format(product.price),
                        style: TextStyle(
                          fontSize: 20,
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
                  // --- Full-width solid button ---
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: isPlaceholder
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ProductDetailPage(
                                    product: product,
                                    catalogue: widget.catalogue,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blueDark,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child:
                          Text(isPlaceholder ? 'Sample item' : 'View details'),
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

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded image tile at the top-left of the card: shows the photo the admin
/// uploaded when there is one, otherwise the generated labelled bottle shot
/// for this medicine, or a soft placeholder tile.
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
        child: product.hasPhoto
            ? Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.network(
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
              )
            : Image.network(
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

/// Amber pill badge (like the GLOBAL badge on the framed source cards).
class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

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

/// Thin dashed rule between the name block and the spec table.
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

/// Sample medicine used for the placeholder cards (values verbatim from the
/// pharmaexport source catalogue) shown while the live catalogue is empty.
class _PlaceholderMedicine {
  final String name;
  final String manufacturer;
  final String category;
  final String packing;
  final double price;
  final int moq;

  const _PlaceholderMedicine({
    required this.name,
    required this.manufacturer,
    required this.category,
    required this.packing,
    required this.price,
    required this.moq,
  });
}

const List<_PlaceholderMedicine> _placeholderMedicines = [
  _PlaceholderMedicine(
      name: 'Pregabalin 300mg',
      manufacturer: 'Sample Manufacturer',
      category: 'Neurology',
      packing: '1 x 10',
      price: 1.30,
      moq: 10),
  _PlaceholderMedicine(
      name: 'Sildenafil 100mg',
      manufacturer: 'Sample Manufacturer',
      category: 'Cardiology',
      packing: '1 x 10',
      price: 2.50,
      moq: 10),
  _PlaceholderMedicine(
      name: 'Tadalafil 20mg',
      manufacturer: 'Sample Manufacturer',
      category: 'Cardiology',
      packing: '1 x 10',
      price: 0.50,
      moq: 10),
  _PlaceholderMedicine(
      name: 'Azithromycin 250mg',
      manufacturer: 'Sample Manufacturer',
      category: 'Antibiotic',
      packing: '1 x 6',
      price: 1.20,
      moq: 6),
  _PlaceholderMedicine(
      name: 'Tapentadol 100mg',
      manufacturer: 'Sample Manufacturer',
      category: 'Neurology',
      packing: '1 x 10',
      price: 2.20,
      moq: 10),
  _PlaceholderMedicine(
      name: 'Gabapentin 800mg',
      manufacturer: 'Sample Manufacturer',
      category: 'Neurology',
      packing: '1 x 10',
      price: 2.00,
      moq: 10),
];
