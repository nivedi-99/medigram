import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import '../widgets/medicine_bottle_label.dart';
import 'product_detail_page.dart';

/// Labelled medicine showcase — the pharmaexport-style medicine cards framed
/// into MediGram.
///
/// Purely additive: a read-only view over the same [ProductRecord] list the
/// Export Catalogue already loads. Each card shows the medicine "photo" (a
/// bottle labelled with the medicine name), the name itself, generic line,
/// spec rows and price. Tapping a card opens the existing product detail
/// page — no catalogue behaviour is changed.
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
              // Placeholder cards of sample medicines fill the page while the
              // live catalogue is still empty.
              child: products.isEmpty
                  ? _buildSampleCatalogue()
                  : _buildGrid(products, samples: false),
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
    final items = _placeholderMedicines
        .map((m) => ProductRecord(
              id: 'sample-${m.name}',
              name: m.name,
              category: m.category,
              manufacturer: m.manufacturer,
              price: m.price,
              minOrderQty: m.moq,
            ))
        .toList();
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

  Widget _buildGrid(List<ProductRecord> items, {required bool samples}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.74,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _MedicineLabelCard(
            product: items[i],
            isPlaceholder: samples,
          ),
        ),
      ),
    );
  }
}

/// Maps a medicine name to its generated image slug:
/// 'Pregabalin 300mg' -> 'pregabalin-300mg'. Must stay in sync with
/// tool/generate_label_images.dart, which writes the files.
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// One framed medicine card: category badge + verified stamp, the labelled
/// bottle photo, medicine name, generic line, spec table and price.
class _MedicineLabelCard extends StatelessWidget {
  final ProductRecord product;
  final bool isPlaceholder;

  const _MedicineLabelCard({
    required this.product,
    this.isPlaceholder = false,
  });

  String get _generic =>
      product.manufacturer.isEmpty ? 'General' : product.manufacturer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Top row: category badge + verified stamp ---
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.blueDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isPlaceholder ? Icons.sell_rounded : Icons.verified_rounded,
                size: 13,
                color: isPlaceholder ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: 3),
              Text(
                isPlaceholder ? 'SAMPLE' : 'VERIFIED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isPlaceholder ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // --- The labelled bottle "photo": the generated product shot with
          // the medicine name labelled onto the bottle. Falls back to the
          // live-drawn labelled bottle for medicines that don't have a
          // generated shot yet. ---
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blueLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  'assets/products/labels/${_slug(product.name)}.png',
                  fit: BoxFit.contain,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                      wasSynchronouslyLoaded
                          ? child
                          : AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              child: child,
                            ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => LayoutBuilder(
                    builder: (context, constraints) => MedicineBottleLabel(
                      medicineName: product.name,
                      subtitle: _generic,
                      footer:
                          'MOQ ${product.minOrderQty} unit${product.minOrderQty == 1 ? '' : 's'}',
                      width: (constraints.maxWidth * 0.62)
                          .clamp(96.0, 132.0)
                          .toDouble(),
                      height: constraints.maxHeight * 0.94,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // --- Medicine name + generic line ---
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Generic - $_generic',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          // --- Spec table (rule above, like the framed HTML card) ---
          Container(
            padding: const EdgeInsets.only(top: 7),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                _specRow('Manufacturer',
                    product.manufacturer.isEmpty ? '-' : product.manufacturer),
                _specRow('Category', product.category),
                _specRow(
                    'Min. order',
                    '${product.minOrderQty} '
                    'unit${product.minOrderQty == 1 ? '' : 's'}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // --- Price + details button ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyService.format(product.price),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blueDark,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '/ unit',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              // Placeholder medicines are not in the live catalogue, so there
              // is nothing to open.
              onPressed: isPlaceholder
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductDetailPage(product: product),
                        ),
                      );
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blueDark,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(isPlaceholder ? 'Sample item' : 'View details'),
            ),
          ),

        ],
      ),
    );
  }
  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
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
                fontSize: 10.5,
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

