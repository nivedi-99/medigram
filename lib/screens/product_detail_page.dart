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
/// Shows the category product shot, brand/molecule identity, the strengths
/// and supplier details (kept verbatim from the catalogue description), MOQ
/// and price, plus add-to-order and a pre-filled WhatsApp quotation inquiry.
///
/// In guest mode (public catalogue), "Add to order" prompts the visitor to
/// sign in via [onRequiresLogin]; the WhatsApp quotation stays available.
class ProductDetailPage extends StatelessWidget {
  final ProductRecord product;
  final bool guestMode;
  final VoidCallback? onRequiresLogin;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.guestMode = false,
    this.onRequiresLogin,
  });

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _openImageViewer(context),
                      child: Stack(
                        children: [
                          _ProductImage(
                              source: _photoSource,
                              fallbackAsset: product.imageAsset,
                              label: product.name),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
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
                            background:
                                AppColors.blueLight.withValues(alpha: 0.6),
                            foreground: AppColors.blueMid),
                        if (product.strength.isNotEmpty)
                          _chip('Strength - ${product.strength}',
                              background:
                                  AppColors.warning.withValues(alpha: 0.15),
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
                          _infoRow(Icons.factory_rounded, 'Manufacturer',
                              product.manufacturer),
                        _infoRow(Icons.category_rounded, 'Category',
                            product.category),
                        if (product.strength.isNotEmpty)
                          _infoRow(Icons.medication_rounded, 'Strength',
                              product.strength),
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
                    const SizedBox(height: 26),
                    _buildActions(context, quotationMessage),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Best available photo: the admin-uploaded image when present, otherwise
  /// the bundled category product shot.
  String get _photoSource =>
      product.imageUrl.isNotEmpty ? product.imageUrl : product.imageAsset;

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
