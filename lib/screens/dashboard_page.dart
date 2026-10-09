import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/cart_service.dart';
import '../services/currency_service.dart';
import '../widgets/region_picker.dart';
import 'quotation_page.dart';
import '../widgets/theme_toggle.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/export_video_view.dart';

/// Lemon-yellow canvas behind the logged-in dashboard (light mode only).
/// Dark mode keeps the deep-teal palette from [AppColors].
const Color _lemonBg = Color(0xFFFFF176);

/// Export/promo film embedded in the dashboard video card.
///
/// Swap this for your own video: a direct MP4/WebM link plays in an inline
/// HTML5 player, and a YouTube link (`youtube.com` / `youtu.be`) plays in an
/// embedded iframe.
const String kExportVideoUrl =
    'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

class DashboardPage extends StatelessWidget {
  final Customer customer;
  final String companyName;
  final int unreadNotifications;
  final VoidCallback onOpenChatbot;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final List<ProductRecord> products;

  const DashboardPage({
    super.key,
    required this.customer,
    required this.companyName,
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

  /// Medicines highlighted in the horizontal strip.
  List<ProductRecord> get _featured => products.take(4).toList();

  /// Medicines laid out in the responsive grid below.
  List<ProductRecord> get _gridProducts => products.take(8).toList();

  @override
  Widget build(BuildContext context) {
    final Color pageBg = AppColors.isDark ? AppColors.bg : _lemonBg;
    return Container(
      color: pageBg,
      child: CustomScrollView(
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
                          style: TextStyle(
                              fontSize: 13.5, color: AppColors.textMuted),
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
                  const RegionPicker(),
                  const SizedBox(width: 6),
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
                      icon: const Icon(Icons.smart_toy_rounded,
                          color: Colors.white),
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
          const SliverToBoxAdapter(
            child: SectionTitle(title: 'Featured Medicines'),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 202,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _featured.length,
                itemBuilder: (context, index) =>
                    _MedicineStripCard(product: _featured[index]),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionTitle(title: 'Export Video'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _exportVideoCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.movie_rounded,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'From our export floor — packaging, QA checks and dispatch, end to end.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textMuted),
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
                itemBuilder: (context, index) =>
                    _HoverChip(label: _categories[index]),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionTitle(title: 'Featured Medicine Information'),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.crossAxisExtent;
              final int columns = width < 620 ? 2 : (width < 1000 ? 3 : 4);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 262,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _MedicineGridCard(product: _gridProducts[index]),
                    childCount: _gridProducts.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
        ],
      ),
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
                  style: TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Rounded 16:9 card embedding the export/promo video.
  Widget _exportVideoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: AppColors.isDark
                    ? const Color(0xFF04262C)
                    : const Color(0xFF05353F),
              ),
              buildExportVideoPlayer(videoUrl: kExportVideoUrl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal highlight-strip medicine card with hover VFX
/// (lift + glow + photo zoom + arrow reveal).
class _MedicineStripCard extends StatefulWidget {
  final ProductRecord product;

  const _MedicineStripCard({required this.product});

  @override
  State<_MedicineStripCard> createState() => _MedicineStripCardState();
}

class _MedicineStripCardState extends State<_MedicineStripCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ProductRecord p = widget.product;
    final bool hasPrice = p.price > 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hover ? 1.035 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 212,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hover
                  ? AppColors.emerald.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.shadow.withValues(alpha: _hover ? 0.16 : 0.06),
                blurRadius: _hover ? 20 : 12,
                offset: Offset(0, _hover ? 8 : 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening ${p.name}...')),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 112,
                      width: double.infinity,
                      child: AnimatedScale(
                        scale: _hover ? 1.08 : 1,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        child: _productImage(p),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.manufacturer.isEmpty
                                ? p.category
                                : p.manufacturer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blueDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                hasPrice
                                    ? CurrencyService.format(p.price)
                                    : 'On request',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const Spacer(),
                              AnimatedOpacity(
                                opacity: _hover ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.arrow_forward_rounded,
                                    size: 18, color: AppColors.emerald),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid medicine card: photo header, category badge, price + MOQ and an
/// add-to-quotation button, with hover VFX (lift + glow + photo zoom).
class _MedicineGridCard extends StatefulWidget {
  final ProductRecord product;

  const _MedicineGridCard({required this.product});

  @override
  State<_MedicineGridCard> createState() => _MedicineGridCardState();
}

class _MedicineGridCardState extends State<_MedicineGridCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ProductRecord p = widget.product;
    final bool hasPrice = p.price > 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hover
                ? AppColors.emerald.withValues(alpha: 0.45)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: _hover ? 0.18 : 0.06),
              blurRadius: _hover ? 24 : 12,
              offset: Offset(0, _hover ? 12 : 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening ${p.name}...')),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedScale(
                          scale: _hover ? 1.08 : 1,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          child: _productImage(p),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.warning
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              p.category.toUpperCase(),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: Color(0xFFB9971F),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            p.manufacturer.isEmpty
                                ? p.category
                                : p.manufacturer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blueDark,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hasPrice
                                      ? '${CurrencyService.format(p.price)} / unit'
                                      : 'Price on request',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MOQ ${p.minOrderQty}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 34,
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                CartService.add(p);
                                // Quotation & payment hub: pay now or get a quote.
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => const QuotationPage()),
                                );
                              },
                              icon: const Icon(Icons.add_shopping_cart_rounded,
                                  size: 15),
                              label: const Text('Add'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _hover ? AppColors.blueMid : AppColors.pink,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

/// Category chip with hover VFX (lift + tint + glow).
class _HoverChip extends StatefulWidget {
  final String label;

  const _HoverChip({required this.label});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: _hover ? AppColors.pinkLight : AppColors.card,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _hover
                ? AppColors.emerald.withValues(alpha: 0.5)
                : AppColors.border,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _hover ? AppColors.blueMid : AppColors.blueDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Product photo with graceful fallbacks: admin upload → labelled bottle
/// shot → category shot → soft medication-icon tile.
Widget _productImage(ProductRecord product) {
  Widget iconTile() => Container(
        color: AppColors.blueLight.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Icon(
          Icons.medication_rounded,
          size: 34,
          color: AppColors.blueMid.withValues(alpha: 0.7),
        ),
      );

  Widget categoryShot() => Image.network(
        product.imageAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => iconTile(),
      );

  Widget labelledShot() => Image.network(
        'assets/products/labels/${_slug(product.name)}.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => categoryShot(),
      );

  if (product.hasPhoto && product.imageUrl.isNotEmpty) {
    return Image.network(
      product.imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => labelledShot(),
    );
  }
  return labelledShot();
}

/// Mirrors the asset slug convention used by the generated bottle labels.
String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

class _NotificationBell extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NotificationBell({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onTap,
            icon: Icon(Icons.notifications_none_rounded,
                color: AppColors.blueDark),
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






