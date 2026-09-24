import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/cart_service.dart';
import '../services/currency_service.dart';
import '../widgets/region_picker.dart';
import 'quotation_page.dart';
import '../widgets/theme_toggle.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

/// A short editorial article shown in the dashboard blog strip.
class _BlogPost {
  final String tag;
  final String title;
  final String excerpt;
  final String body;
  final String meta;
  const _BlogPost(this.tag, this.title, this.excerpt, this.body, this.meta);
}

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

  /// First few live products for the featured section.
  List<ProductRecord> get _featured => products.take(4).toList();


  @override
  Widget build(BuildContext context) {
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
        const SliverToBoxAdapter(
          child: SectionTitle(title: 'From the MediGram Blog'),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _blogPosts.length,
              itemBuilder: (context, index) =>
                  _blogCard(context, _blogPosts[index]),
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
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: AppColors.border),
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

  static const List<_BlogPost> _blogPosts = [
    _BlogPost(
      'Regulatory',
      'WHO-GMP vs USFDA: Which Certification Does Your Market Need?',
      'Import rules differ by destination - match the right certification to your market before you place an order.',
      'Every country sets its own entry bar for medicines. WHO-GMP certification is the global baseline accepted across Africa, South-East Asia and Latin America, while USFDA approval unlocks the United States and is widely respected by other stringent regulators such as the UK MHRA and Health Canada.\n\nBefore you finalise a product, ask for the exact site certificate - not just the company certificate. A manufacturing site may hold WHO-GMP approval for tablets but not for injectables, and a single expired certificate can hold an entire consignment at customs.\n\nEvery MediGram catalogue listing shows the certifications attached to its manufacturing site, and our trade desk confirms the paperwork for your destination country before you commit to a purchase order.',
      '6 min read • Oct 2026',
    ),
    _BlogPost(
      'Cold Chain',
      'Shipping Vaccines and Insulin: A 2-8°C Playbook',
      'Temperature-controlled logistics explained - gel packs, data loggers and what happens at every hand-off.',
      'Cold-chain products lose potency long before they look damaged. A validated 2-8°C lane uses qualified gel packs, insulated liners and pre-cooled boxes so the product never sees a temperature excursion, even when a tarmac in transit crosses 45°C.\n\nEvery shipment travels with a USB data logger. On arrival, download the log before signing acceptance: a flat line between 2°C and 8°C proves the chain held, and any excursion becomes evidence for a claim rather than a dispute.\n\nMediGram books cold-chain capacity as a default for vaccine, insulin and biologic orders, and the trade desk shares the logger report with every consignment set.',
      '5 min read • Sep 2026',
    ),
    _BlogPost(
      'Documentation',
      'Export Paperwork 101: From Commercial Invoice to Bill of Lading',
      'Every document in a medicine shipment, who issues it, and the sequence it arrives in.',
      'A standard medicine export moves on five core documents: the commercial invoice, the packing list, the certificate of analysis for each batch, the certificate of pharmaceutical product (CPP) where the destination asks for one, and the airway or ocean bill of lading that titles the shipment.\n\nMost customs delays are paperwork delays - a mismatched batch number, an HS code that does not match the invoice wording, or a CPP issued for the wrong strength. Checking the five documents against each other before the flight is booked costs minutes; fixing them after arrival costs weeks.\n\nMediGram issues a complete, cross-checked document pack with every order and keeps copies in your account so audits stay a formality.',
      '7 min read • Sep 2026',
    ),
    _BlogPost(
      'Sourcing',
      'Five Checks Before You Trust a Medicine Supplier',
      'Verify licences, batch COAs and traceability before wiring a single rupee.',
      'Five checks separate a reliable supplier from an expensive lesson. One: a valid wholesale or manufacturing licence you can verify with the issuing authority. Two: a batch-specific certificate of analysis, not a generic product brochure.\n\nThree: traceable batch numbers that match what the regulator database shows for that site. Four: a real pharmacovigilance or complaints contact that answers. Five: commercial transparency - a written quotation with Incoterms, lead time and validity.\n\nMediGram was built around those checks: every partner is licence-verified, every listing carries its batch documentation, and every quote is itemised and held to its validity window.',
      '4 min read • Aug 2026',
    ),
  ];

  Widget _blogCard(BuildContext context, _BlogPost post) {
    return Container(
      width: 270,
      margin: const EdgeInsets.only(right: 12),
      child: SoftCard(
        onTap: () => _openPost(context, post),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pinkLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(post.tag,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sandDeep)),
            ),
            const SizedBox(height: 10),
            Text(post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: AppColors.textDark)),
            const SizedBox(height: 6),
            Expanded(
              child: Text(post.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textMuted)),
            ),
            Row(
              children: [
                Text(post.meta,
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: AppColors.blueDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPost(BuildContext context, _BlogPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 34),
                children: [
                  Center(
                    child: Container(
                      height: 5,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pinkLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(post.tag,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.sandDeep)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(post.title,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: AppColors.textDark)),
                  const SizedBox(height: 6),
                  Text(post.meta,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                  const Divider(height: 26),
                  for (final paragraph in post.body.split('\n\n'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(paragraph,
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: AppColors.textDark)),
                    ),
                ],
              ),
            );
          },
        );
      },
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
                      style: TextStyle(
                        height: 1.35,
                        fontSize: 12.5,
                        color: AppColors.textMuted,
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
                            ? '${CurrencyService.format(product.price)} / unit'
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
    final noticeBg = AppColors.isDark ? const Color(0xFF2E2A1A) : const Color(0xFFFFF4D9);
    final noticeFg = AppColors.isDark ? const Color(0xFFFBBF24) : const Color(0xFFB87900);
    final noticeText = AppColors.isDark ? const Color(0xFFE8D9A8) : const Color(0xFF735400);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: noticeBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: noticeFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Medicine information is for educational purposes. Consult a qualified healthcare professional and upload a valid prescription before ordering prescription-only medicines.',
              style: TextStyle(color: noticeText, height: 1.35, fontSize: 13),
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
        color: AppColors.card,
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
