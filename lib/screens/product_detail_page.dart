import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_launcher.dart';
import '../services/cart_service.dart';
import '../services/currency_service.dart';
import 'quotation_page.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/whatsapp_chat_button.dart';

/// Full product detail view - opened when a catalogue card is tapped.
///
/// Two-column layout: the left column shows the full product picture and all
/// product information; the right side bar lists similar products (same
/// category first) and a browse panel for the rest of the catalogue. Tapping
/// a similar product swaps the detail view in place, so Back always returns
/// to the catalogue. In guest mode (public catalogue), "Add to order"
/// prompts the visitor to sign in via [onRequiresLogin]; the WhatsApp
/// quotation stays available.
class ProductDetailPage extends StatefulWidget {
  final ProductRecord product;

  /// The full live catalogue; powers the similar-products side bar. When it
  /// is empty the side bar degrades to the browse section only.
  final List<ProductRecord> catalogue;
  final bool guestMode;
  final VoidCallback? onRequiresLogin;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.catalogue = const [],
    this.guestMode = false,
    this.onRequiresLogin,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  /// The product currently shown; swaps in place when a similar product is
  /// tapped in the side bar (Back still returns to the catalogue).
  late ProductRecord _product;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ProductRecord get product => _product;
  bool get guestMode => widget.guestMode;
  VoidCallback? get onRequiresLogin => widget.onRequiresLogin;

  /// Swaps the detail view to [next] and scrolls back to the top.
  void _switchTo(ProductRecord next) {
    if (next.id == _product.id) return;
    setState(() => _product = next);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final body = _buildMainBody(context);
          final sidebar = _ProductSidebar(
            current: _product,
            catalogue: widget.catalogue,
            scrollable: wide,
            onSelect: _switchTo,
            onViewAll: () => Navigator.of(context).maybePop(),
          );
          final header = _buildHeader(context);
          if (!wide) {
            // Narrow: the side bar stacks under the main column.
            return SingleChildScrollView(
              controller: _scroll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 12),
                        body,
                        const SizedBox(height: 20),
                        sidebar,
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          // Wide: two independent scrollables — main column on the left,
          // the similar-products side bar pinned on the right.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scroll,
                              padding: const EdgeInsets.only(bottom: 32),
                              child: body,
                            ),
                          ),
                          const SizedBox(width: 22),
                          SizedBox(
                            width: 340,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: sidebar,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Main (left) column: the full product picture, identity chips, price
  /// and MOQ, the information cards and the ordering actions.
  Widget _buildMainBody(BuildContext context) {
    final generic =
        product.manufacturer.isEmpty ? 'General' : product.manufacturer;

    // Catalogue description stores strengths and supplier/notes separated by
    // a pipe character — shown to buyers as separate description lines.
    final sep = String.fromCharCode(124);
    final parts = product.description
        .split(sep)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final quotationMessage = 'Hello MediGram! Please send me a quotation for '
        '${product.name} ($generic), MOQ: ${product.minOrderQty} units.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _openImageViewer(context),
          child: Stack(
            children: [
              _ProductImage(
                  source:
                      product.hasPhoto ? product.imageUrl : product.imageAsset,
                  fallbackAsset: product.imageAsset,
                  label: product.name),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded,
                          size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Tap to enlarge',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          product.name,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(product.category,
                background: AppColors.blueLight,
                foreground: AppColors.blueDark),
            _chip('Generic - $generic',
                background: AppColors.blueLight.withValues(alpha: 0.6),
                foreground: AppColors.blueMid),
            if (product.strength.isNotEmpty)
              _chip('Strength - ${product.strength}',
                  background: AppColors.warning.withValues(alpha: 0.15),
                  foreground: AppColors.warning),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _infoTile(
                'Min. order qty',
                '${product.minOrderQty} unit${product.minOrderQty == 1 ? '' : 's'}',
                Icons.inventory_2_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoTile(
                'Price',
                CurrencyService.priceLine(product.price),
                Icons.sell_rounded,
              ),
            ),
          ],
        ),
        if (product.strength.isNotEmpty ||
            product.manufacturer.isNotEmpty ||
            product.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          _infoCard('Product information', [
            if (product.manufacturer.isNotEmpty)
              _infoRow(
                  Icons.factory_rounded, 'Manufacturer', product.manufacturer),
            _infoRow(Icons.category_rounded, 'Category', product.category),
            if (product.strength.isNotEmpty)
              _infoRow(Icons.medication_rounded, 'Strength', product.strength),
            _infoRow(
              Icons.inventory_2_rounded,
              'Min. order quantity',
              '${product.minOrderQty} unit${product.minOrderQty == 1 ? '' : 's'}',
            ),
            _infoRow(Icons.sell_rounded, 'Unit price',
                CurrencyService.priceLine(product.price)),
          ]),
        ],
        if (product.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailCard(
            'Description',
            parts.isEmpty
                ? 'Details available on request - contact the '
                    'MediGram trade desk.'
                : parts.map((p) => '•  $p').join('\n'),
          ),
        ],
        const SizedBox(height: 12),
        _detailCard('Typical uses', _usesForCategory(product.category)),
        const SizedBox(height: 8),
        Text(
          'Category information is provided for general export '
          'guidance only. Always confirm indications, dosage and '
          'regulatory suitability with a qualified professional '
          'and the MediGram trade desk before ordering.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            fontStyle: FontStyle.italic,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 26),
        _buildActions(context, quotationMessage),
      ],
    );
  }

  /// Best available photo: the admin-uploaded image when present, otherwise
  /// the bundled category product shot.
  String get _photoSource =>
      product.hasPhoto ? product.imageUrl : product.imageAsset;

  /// Fullscreen, pinch-zoomable view of the product photo.
  void _openImageViewer(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image.network(
                  _photoSource,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.network(
                    product.imageAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.blueLight.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        product.name.isEmpty
                            ? '?'
                            : product.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blueDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back to catalogue',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textDark),
        ),
        const SizedBox(width: 4),
        Text(
          'Product details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _chip(String label,
      {required Color background, required Color foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.blueMid),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Grouped "Product information" card with icon-labelled detail rows.
  Widget _infoCard(String title, List<Widget> rows) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  /// One icon + label + value row inside the product information card.
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.blueMid),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(String title, String body) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, String quotationMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: guestMode
              ? (onRequiresLogin ?? () {})
              : () {
                  CartService.add(product);
                  // Quotation & payment hub: pay now or request a quotation.
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const QuotationPage()),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blueDark,
            foregroundColor: AppColors.onPrimary,
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text(
            'Add to order',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final opened = await openExternalUrl(
                WhatsAppChatButton.deepLink(quotationMessage));
            if (opened || !context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chat with us on WhatsApp: +91 95884 23570'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1FA855),
            side: const BorderSide(color: Color(0xFF25D366), width: 1.6),
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.chat_rounded),
          label: const Text(
            'Ask quotation on WhatsApp',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    );
  }
}

/// Product photo with layered fallbacks: the admin-uploaded photo (or its
/// canonical storage path) first, then the bundled category product shot,
/// then a first-letter avatar — same loading/error treatment as the
/// catalogue cards.
class _ProductImage extends StatelessWidget {
  final String source;
  final String fallbackAsset;
  final String label;

  const _ProductImage({
    required this.source,
    required this.fallbackAsset,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          source,
          fit: BoxFit.cover,
          width: double.infinity,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
              wasSynchronouslyLoaded
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      child: child,
                    ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.blueLight.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Image.network(
            fallbackAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.blueLight.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Text(
                label.isEmpty ? '?' : label.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blueDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Deep, buyer-friendly "typical uses" guidance for a catalogue category.
/// General export guidance — not medical advice (a disclaimer is shown
/// alongside it on the detail page).
String _usesForCategory(String category) {
  final c = category.toLowerCase();
  if (c.contains('pain') || c.contains('analges')) {
    return 'Pain Killers combine analgesic and anti-inflammatory actives that '
        'are commonly used to relieve mild to moderate pain, reduce fever and '
        'control inflammation associated with headaches, musculoskeletal '
        'strain, dental pain and post-procedural recovery. Formulations are '
        'supplied for institutional, retail and export programmes.';
  }
  if (c.contains('ed ') || c.contains('erectile')) {
    return 'ED Medicines contain PDE-5 inhibitors that are commonly used for '
        'the treatment of erectile dysfunction in adult men, improving '
        'blood-flow response when sexually stimulated. Supply is intended for '
        'licensed pharmaceutical distributors and requires a valid '
        'prescription in the destination market.';
  }
  if (c.contains('anxiety') || c.contains('depress')) {
    return 'Anti-Anxiety medicines are commonly used for the short-term '
        'management of generalised anxiety, stress-related disorders, panic '
        'symptoms and associated sleep disturbance, under the supervision of '
        'a qualified medical professional.';
  }
  if (c.contains('antibiotic') || c.contains('antibacterial')) {
    return 'Antibiotics are commonly used for the treatment of confirmed '
        'bacterial infections, including respiratory, urinary, skin and '
        'gastrointestinal presentations. Responsible-use guidance and a '
        'completed prescription course are strongly advised.';
  }
  if (c.contains('diabet')) {
    return 'Anti-Diabetic medicines are commonly used to help control blood '
        'sugar levels in type 2 diabetes mellitus, supporting long-term '
        'glycaemic management alongside diet, exercise and routine '
        'monitoring.';
  }
  if (c.contains('parasit') || c.contains('worm')) {
    return 'Anti-Parasitic medicines are commonly used for the treatment and '
        'control of intestinal and tissue parasitic infections, including '
        'mass-administration and public-health programmes.';
  }
  if (c.contains('allerg') || c.contains('histam')) {
    return 'Anti-Allergic medicines are commonly used to relieve allergy '
        'symptoms such as sneezing, runny nose, allergic rhinitis, itching '
        'and hives, and are supplied for both retail and institutional '
        'export packs.';
  }
  if (c.contains('cardio') || c.contains('heart') || c.contains('cardiac')) {
    return 'Cardio Care medicines are commonly used in the management of '
        'high blood pressure, cholesterol and other cardiovascular '
        'conditions, supporting long-term heart-health therapy under '
        'medical supervision.';
  }
  if (c.contains('vitamin') ||
      c.contains('supplement') ||
      c.contains('nutri')) {
    return 'Vitamins and Supplements are commonly used to correct nutritional '
        'deficiencies, support bone health, immunity and general wellbeing, '
        'and are supplied in export-ready packs for retail and institutional '
        'programmes.';
  }
  if (c.contains('neuro') || c.contains('epilep')) {
    return 'Neurology medicines are commonly used to support the management '
        'of neuropathic pain, seizures and other neurological conditions '
        'under specialist supervision.';
  }
  if (c.contains('derma') || c.contains('skin')) {
    return 'Dermatology medicines are commonly used for the treatment of '
        'skin conditions such as infections, inflammation, acne and fungal '
        'presentations, in topical and oral formulations.';
  }
  if (c.contains('gastro') || c.contains('acidity') || c.contains('ulcer')) {
    return 'Gastro medicines are commonly used to manage acidity, heartburn, '
        'ulcers and other stomach-related conditions, supporting digestive '
        'health under medical guidance.';
  }
  return 'This category covers quality-assured medicines sourced from '
      'WHO-GMP certified manufacturers for institutional and export supply. '
      'Contact the MediGram trade desk for the complete product profile, '
      'composition and regulatory documentation.';
}

/// Right-hand side bar of the product detail page: similar products (same
/// category first, then same manufacturer, then the rest) plus a browse
/// panel with category filters and a shortcut back to the full catalogue.
class _ProductSidebar extends StatefulWidget {
  final ProductRecord current;
  final List<ProductRecord> catalogue;

  /// True when the page gives this side bar a bounded height (wide layout)
  /// so its list scrolls independently; false when it is stacked under the
  /// main column (narrow layout) and takes its natural height.
  final bool scrollable;
  final ValueChanged<ProductRecord> onSelect;
  final VoidCallback onViewAll;

  const _ProductSidebar({
    required this.current,
    required this.catalogue,
    required this.scrollable,
    required this.onSelect,
    required this.onViewAll,
  });

  @override
  State<_ProductSidebar> createState() => _ProductSidebarState();
}

class _ProductSidebarState extends State<_ProductSidebar> {
  /// Category filter of the browse panel (null = all products).
  String? _browseCategory;

  /// Similar products: same category first, backfilled with the same
  /// manufacturer and then everything else. Never includes the current item.
  List<ProductRecord> _similarProducts() {
    final current = widget.current;
    final others = widget.catalogue.where((p) => p.id != current.id).toList();
    int rank(ProductRecord p) {
      if (p.category == current.category) return 0;
      if (p.manufacturer.isNotEmpty && p.manufacturer == current.manufacturer) {
        return 1;
      }
      return 2;
    }

    others.sort((a, b) => rank(a).compareTo(rank(b)));
    return others.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final similar = _similarProducts();
    final categories = widget.catalogue
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    final browse = _browseCategory == null
        ? widget.catalogue
        : widget.catalogue.where((p) => p.category == _browseCategory).toList();

    final list = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (similar.isEmpty)
            const _SidebarHint('Similar products will appear here as the '
                'catalogue grows.')
          else
            for (final p in similar)
              _SidebarTile(product: p, onTap: () => widget.onSelect(p)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'BROWSE THE CATALOGUE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SidebarChip(
                    label: 'All',
                    selected: _browseCategory == null,
                    onTap: () => setState(() => _browseCategory = null),
                  ),
                  for (final c in categories)
                    _SidebarChip(
                      label: c,
                      selected: _browseCategory == c,
                      onTap: () => setState(() => _browseCategory = c),
                    ),
                ],
              ),
            ),
          if (browse.isEmpty)
            const _SidebarHint('No products in this category yet.')
          else
            for (final p in browse)
              _SidebarTile(
                product: p,
                highlighted: p.id == widget.current.id,
                onTap:
                    p.id == widget.current.id ? null : () => widget.onSelect(p),
              ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'SIMILAR PRODUCTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          if (widget.scrollable) Expanded(child: list) else list,
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: widget.onViewAll,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blueDark,
                side: BorderSide(
                  color: AppColors.blueMid.withValues(alpha: 0.5),
                ),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.grid_view_rounded, size: 18),
              label: const Text(
                'View all products',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact row in the side bar: thumbnail, name, price and category.
/// Tapping swaps the detail page to that product; the current product is
/// highlighted (and not tappable).
class _SidebarTile extends StatelessWidget {
  final ProductRecord product;
  final bool highlighted;
  final VoidCallback? onTap;

  const _SidebarTile({
    required this.product,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: highlighted
            ? AppColors.blueLight.withValues(alpha: 0.45)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlighted ? AppColors.blueMid : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                _SidebarThumb(product: product),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        CurrencyService.priceLine(product.price),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blueDark,
                        ),
                      ),
                      if (product.category.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muted hint line shown when a side bar section has nothing to list.
class _SidebarHint extends StatelessWidget {
  final String text;

  const _SidebarHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Rounded 52px thumbnail with the same layered fallbacks as the catalogue
/// cards: uploaded photo, then the generated labelled bottle shot, then a
/// soft medication-icon tile.
class _SidebarThumb extends StatelessWidget {
  final ProductRecord product;

  const _SidebarThumb({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.blueLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Image.network(
        product.hasPhoto ? product.imageUrl : product.imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.network(
          'assets/products/labels/${_sidebarSlug(product.name)}.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.blueLight.withValues(alpha: 0.55),
            alignment: Alignment.center,
            child: Icon(
              Icons.medication_rounded,
              size: 22,
              color: AppColors.blueMid.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small category filter pill used in the side bar's browse panel.
class _SidebarChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueDark : AppColors.blueLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: selected ? AppColors.onPrimary : AppColors.blueDark,
          ),
        ),
      ),
    );
  }
}

/// Maps a medicine name to its generated image slug (same convention as the
/// catalogue cards): 'Pregabalin 300mg' -> 'pregabalin-300mg'.
String _sidebarSlug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
