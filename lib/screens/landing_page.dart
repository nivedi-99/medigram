import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/med_background.dart';
import '../widgets/region_picker.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/whatsapp_chat_button.dart';

/// Public marketing landing page - light "Medina-style" storefront shown to
/// signed-out visitors: info strip, clean header, auto-advancing hero
/// slider, overlapping feature cards, category grid, testimonials, news
/// and a dark footer. The region selector lives in the top strip.
class LandingPage extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  /// Opens the public medicine catalogue (guest browse, no login needed).
  final VoidCallback onBrowse;

  const LandingPage({
    super.key,
    required this.onLogin,
    required this.onSignup,
    required this.onBrowse,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _phone = '+91 95884 23570';

  final ScrollController _scroll = ScrollController();
  final PageController _heroPager = PageController();
  final PageController _quotePager = PageController();
  Timer? _heroTimer;
  Timer? _quoteTimer;
  int _heroIndex = 0;
  int _quoteIndex = 0;

  final GlobalKey _medicinesKey = GlobalKey();
  final GlobalKey _whyUsKey = GlobalKey();
  final GlobalKey _newsKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  static const _categories = <(String, IconData)>[
    ('''Women's Personal Use''', Icons.health_and_safety_rounded),
    ('ED Medicines', Icons.medication_rounded),
    ('Anti-Anxiety', Icons.self_improvement_rounded),
    ('Pain Killers', Icons.healing_rounded),
  ];

  static const _whyUs = <(IconData, String, String)>[
    (Icons.verified_user_rounded, '100% Genuine Products',
        'Every medicine is sourced from licensed manufacturers and authorised distributors.'),
    (Icons.local_shipping_rounded, 'Fast Worldwide Dispatch',
        'Export shipments leave on schedule with complete documentation for smooth clearance.'),
    (Icons.currency_exchange_rounded, 'Best Export Prices',
        'Direct-from-India pricing with region-wise rates and volume discounts.'),
    (Icons.support_agent_rounded, '24/7 Trade Support',
        'Our desk answers around the clock - on call, email or WhatsApp.'),
  ];

  static const _slides = <(String, String, String)>[
    (
      'B2B PHARMA EXPORT PLATFORM',
      'Genuine Indian Medicines, Delivered Worldwide',
      'Source WHO-GMP certified pharmaceuticals from licensed Indian manufacturers with full export documentation.',
    ),
    (
      'REGION-WISE EXPORT PRICING',
      'Transparent Pricing for Your Market',
      'See live prices for your region, add to cart and pay securely - or request an itemised quotation.',
    ),
    (
      'FAST WORLDWIDE DISPATCH',
      'Reliable Dispatch, Door to Door',
      'Cold-chain aware logistics with invoice, packing list, CoA and every shipping document in order.',
    ),
  ];

  static const _quotes = <(String, String, String)>[
    (
      'Quotation arrived the same evening with every certificate attached. Two shipments in, the paperwork has been flawless.',
      'Amara O.',
      'Pharma Distributor - Lagos',
    ),
    (
      'Prices update for our region automatically, so budgeting a mixed-pallet order takes minutes instead of days.',
      'Daniel K.',
      'Importer - Nairobi',
    ),
    (
      'The trade desk picked up late at night and had our urgent order booked before morning. A genuine partner.',
      'Sofia R.',
      'Procurement Lead - Manila',
    ),
    (
      'Documentation cleared without a single query, and dispatch dates held exactly as promised.',
      'Hassan A.',
      'Wholesaler - Baghdad',
    ),
  ];

  static const _news = <(String, String, String)>[
    (
      'DOCUMENTATION',
      'Preparing Export Documents in 6 Steps',
      'From commercial invoice to certificate of analysis - the paperwork every shipment needs.',
    ),
    (
      'LOGISTICS',
      'Choosing the Right Packaging for Sea and Air',
      'How packaging choices protect potency and keep customs clearance smooth.',
    ),
    (
      'PRICING',
      'Region-Wise Pricing: What Importers Should Know',
      'Why the same medicine can carry a different export price across markets.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_heroPager.hasClients) return;
      final page = _heroPager.page ?? 0;
      final next = (page.round() + 1) % _slides.length;
      _heroPager.animateToPage(next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic);
    });
    _quoteTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_quotePager.hasClients) return;
      final page = _quotePager.page ?? 0;
      final next = (page.round() + 1) % _quotes.length;
      _quotePager.animateToPage(next,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic);
    });
    _heroPager.addListener(() {
      final i = _heroPager.page?.round() ?? 0;
      if (i != _heroIndex && mounted) setState(() => _heroIndex = i);
    });
    _quotePager.addListener(() {
      final i = _quotePager.page?.round() ?? 0;
      if (i != _quoteIndex && mounted) setState(() => _quoteIndex = i);
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _quoteTimer?.cancel();
    _scroll.dispose();
    _heroPager.dispose();
    _quotePager.dispose();
    super.dispose();
  }

  void _browse() => widget.onBrowse();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: MedBackgroundVfx(
        baseColor: AppColors.bg,
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              _header(context),
              _hero(context),
              _overlapCards(context),
              _infoBand(context),
              _bannerCta1(context),
              _whyUsSection(),
              _categoriesSection(context),
              _testimonials(context),
              _bannerCta2(context),
              _newsSection(context),
              _newsletter(context),
              _footer(context),
            ],
          ),
        ),
      ),
      floatingActionButton: const WhatsAppChatButton(),
    );
  }

  // ------------------------------------------------------------------
  // Top info strip + header
  // ------------------------------------------------------------------

  Widget _topBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: const Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call_rounded, size: 15, color: AppColors.blueDark),
            SizedBox(width: 6),
            Text(_phone,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
            SizedBox(width: 16),
            Icon(Icons.location_on_rounded,
                size: 15, color: AppColors.blueDark),
            SizedBox(width: 6),
            Text('Nagpur, Maharashtra, India',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.mail_rounded, size: 15, color: AppColors.blueDark),
            SizedBox(width: 6),
            Text('support@medigram.com',
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
            SizedBox(width: 14),
            RegionPicker(),
            SizedBox(width: 8),
            ThemeToggle(size: 20),
          ]),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final showNav = MediaQuery.sizeOf(context).width >= 980;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _logo(),
          const Spacer(),
          if (showNav) ...[
            _navLink('Medicines', () => _scrollTo(_medicinesKey)),
            _navLink('Why Us', () => _scrollTo(_whyUsKey)),
            _navLink('News', () => _scrollTo(_newsKey)),
            _navLink('Contact', () => _scrollTo(_contactKey)),
            const SizedBox(width: 10),
          ],
          TextButton(
            onPressed: widget.onLogin,
            style: TextButton.styleFrom(foregroundColor: AppColors.textDark),
            child: const Text('Login',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: widget.onSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueDark,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          gradient: AppColors.blueGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.local_pharmacy_rounded,
            color: Colors.white, size: 23),
      ),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MediGram',
            style: TextStyle(
                fontFamily: 'Asap',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        Text('GLOBAL PHARMACEUTICAL EXPORTS',
            style: TextStyle(
                fontSize: 8,
                letterSpacing: 1.6,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
      ]),
    ]);
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ),
      ),
    );
  }
  // ------------------------------------------------------------------
  // Hero slider
  // ------------------------------------------------------------------

  Widget _hero(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      padding: EdgeInsets.fromLTRB(wide ? 64 : 24, 52, wide ? 64 : 24, 112),
      child: Column(
        children: [
          SizedBox(
            height: wide ? 290 : 400,
            child: PageView.builder(
              controller: _heroPager,
              itemCount: _slides.length,
              itemBuilder: (context, i) {
                final (overline, title, sub) = _slides[i];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: Text(overline,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  letterSpacing: 2.2,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                        const SizedBox(height: 20),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Asap',
                                fontSize: wide ? 38 : 26,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                color: Colors.white)),
                        const SizedBox(height: 14),
                        Text(sub,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14.5,
                                height: 1.6,
                                color: Colors.white.withValues(alpha: 0.82))),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _browse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.blueDark,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Browse Medicines'),
                            ),
                            OutlinedButton(
                              onPressed: widget.onSignup,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 1.4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Create Free Account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _slides.length; i++)
                GestureDetector(
                  onTap: () => _heroPager.animateToPage(i,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 7,
                    width: i == _heroIndex ? 26 : 8,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: i == _heroIndex ? 0.95 : 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Overlapping feature cards
  // ------------------------------------------------------------------

  Widget _overlapCards(BuildContext context) {
    final cards = <(IconData, String, String, String, VoidCallback)>[
      (
        Icons.verified_rounded,
        'Certified Supply Chain',
        'WHO-GMP certified products from licensed manufacturers.',
        'Browse medicines',
        _browse,
      ),
      (
        Icons.workspace_premium_rounded,
        '7+ Years of Export',
        'Serving importers and distributors across continents.',
        'Why choose us',
        () => _scrollTo(_whyUsKey),
      ),
      (
        Icons.schedule_rounded,
        'Mon-Sat Dispatch Desk',
        'Orders confirmed 9:00-19:00 IST with live status updates.',
        'Contact us',
        () => _scrollTo(_contactKey),
      ),
    ];
    return Transform.translate(
      offset: const Offset(0, -54),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final c in cards)
                  SizedBox(width: 362, child: _overlapCard(context, c)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlapCard(
      BuildContext context, (IconData, String, String, String, VoidCallback) c) {
    final (icon, title, text, linkLabel, onTap) = c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.blueDark, size: 24),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Asap',
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: AppColors.textMuted)),
          const SizedBox(height: 10),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(linkLabel,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blueDark)),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_rounded,
                    size: 15, color: AppColors.blueDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------------------------------
  // Info band
  // ------------------------------------------------------------------

  Widget _infoBand(BuildContext context) {
    final items = <(IconData, String, String, VoidCallback)>[
      (
        Icons.request_quote_rounded,
        'Request a Quotation',
        'Itemised quotes with certificates, fast.',
        _browse,
      ),
      (
        Icons.inventory_rounded,
        'Bulk and Volume Orders',
        'Tiered pricing on pallets and containers.',
        _browse,
      ),
      (
        Icons.support_agent_rounded,
        'Urgent Requirement?',
        _phone,
        () => _scrollTo(_contactKey),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Wrap(
            spacing: 18,
            runSpacing: 14,
            children: [
              for (final (icon, title, text, onTap) in items)
                SizedBox(
                  width: 362,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: AppColors.pinkLight,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(icon,
                                color: AppColors.blueDark, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontFamily: 'Asap',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark)),
                                const SizedBox(height: 3),
                                Text(text,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 20, color: AppColors.blueDark),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // CTA banner 1
  // ------------------------------------------------------------------

  Widget _bannerCta1(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.blueGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 18,
              runSpacing: 16,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Become a Verified Buyer',
                          style: TextStyle(
                              fontFamily: 'Asap',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(
                        'Create a free trade account to unlock region pricing, '
                        'cart checkout and priority quotations.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.88)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: widget.onSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.blueDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Free Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Why us
  // ------------------------------------------------------------------

  Widget _whyUsSection() {
    return Container(
      key: _whyUsKey,
      margin: const EdgeInsets.only(top: 40),
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              _sectionHeader(
                'WHY MEDIGRAM',
                'What Makes Us Different',
                'A trade desk built for importers: certified stock, honest '
                    'region pricing and documentation that clears first time.',
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final (icon, title, text) in _whyUs)
                    SizedBox(
                      width: 270,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: _cardDeco(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.blueLight,
                                shape: BoxShape.circle,
                              ),
                              child:
                                  Icon(icon, color: AppColors.blueDark, size: 24),
                            ),
                            const SizedBox(height: 14),
                            Text(title,
                                style: const TextStyle(
                                    fontFamily: 'Asap',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                            const SizedBox(height: 7),
                            Text(text,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.6,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Categories
  // ------------------------------------------------------------------

  Widget _categoriesSection(BuildContext context) {
    final tints = <LinearGradient>[
      const LinearGradient(colors: [Color(0xFF2A93C9), Color(0xFF55BBEB)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF1F6E9C), Color(0xFF2A93C9)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF125E93), Color(0xFF1D82BF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF0F4C77), Color(0xFF16649B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];
    return Container(
      key: _medicinesKey,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              _sectionHeader(
                'OUR MEDICINES',
                'Browse by Category',
                'Open the live catalogue as a guest - no account needed to '
                    'compare export prices and prepare an order.',
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (var i = 0; i < _categories.length; i++)
                    _categoryCard(_categories[i].$1, _categories[i].$2, tints[i % tints.length]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryCard(String name, IconData icon, LinearGradient tint) {
    return SizedBox(
      width: 270,
      child: InkWell(
        onTap: _browse,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: _cardDeco(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 110,
                decoration: BoxDecoration(gradient: tint),
                child: Center(
                  child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 44),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontFamily: 'Asap',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Text('Explore catalogue',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blueDark)),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.blueDark),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ------------------------------------------------------------------
  // Testimonials
  // ------------------------------------------------------------------

  Widget _testimonials(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              _sectionHeader(
                'TESTIMONIALS',
                'Trusted by Buyers Worldwide',
                'Notes from distributors and importers who order through MediGram.',
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 240,
                child: PageView.builder(
                  controller: _quotePager,
                  itemCount: _quotes.length,
                  itemBuilder: (context, i) {
                    final (quote, name, role) = _quotes[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: _cardDeco(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.format_quote_rounded,
                                    color: AppColors.blueDark, size: 28),
                                const SizedBox(height: 8),
                                Text(quote,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.7,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textDark)),
                                const Spacer(),
                                Row(
                                  children: [
                                    Container(
                                      height: 34,
                                      width: 34,
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.blueGradient,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(name.substring(0, 1),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                fontFamily: 'Asap',
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textDark)),
                                        Text(role,
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _quotes.length; i++)
                    GestureDetector(
                      onTap: () => _quotePager.animateToPage(i,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 7,
                        width: i == _quoteIndex ? 26 : 8,
                        decoration: BoxDecoration(
                          color: AppColors.blueDark
                              .withValues(alpha: i == _quoteIndex ? 0.9 : 0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // CTA banner 2
  // ------------------------------------------------------------------

  Widget _bannerCta2(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.darkBand,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 18,
              runSpacing: 16,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Need Bulk Pricing?',
                          style: TextStyle(
                              fontFamily: 'Asap',
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(
                        'Volume discounts on pallet and container orders. Tap the '
                        'WhatsApp button anytime - our trade desk replies around the clock.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _browse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Request a Quotation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // News
  // ------------------------------------------------------------------

  Widget _newsSection(BuildContext context) {
    return Container(
      key: _newsKey,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              _sectionHeader(
                'LATEST NEWS',
                'From the Export Desk',
                'Practical notes on documentation, logistics and pricing for pharma importers.',
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  for (final (tag, title, excerpt) in _news)
                    SizedBox(
                        width: 362,
                        child: _newsCard(tag, title, excerpt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _newsCard(String tag, String title, String excerpt) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
              height: 5,
              decoration:
                  const BoxDecoration(gradient: AppColors.blueGradient)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.pinkLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(tag,
                      style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDeep)),
                ),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Asap',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(excerpt,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: AppColors.textMuted)),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Text('MediGram trade desk',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                    SizedBox(width: 6),
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 13, color: AppColors.blueDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------------------------------
  // Newsletter
  // ------------------------------------------------------------------

  Widget _newsletter(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 52),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              const Text('Newsletter',
                  style: TextStyle(
                      fontFamily: 'Asap',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                'Export updates, new product alerts and trade tips - straight to your inbox.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, height: 1.6, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: TextField(
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          InputDecoration(hintText: 'Your e-mail address'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Thanks - you are on the list.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blueDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Subscribe'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Footer
  // ------------------------------------------------------------------

  Widget _footer(BuildContext context) {
    return Container(
      key: _contactKey,
      color: AppColors.darkBand,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 36,
                runSpacing: 28,
                children: [
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                gradient: AppColors.blueGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_pharmacy_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Text('MediGram',
                                style: TextStyle(
                                    fontFamily: 'Asap',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'India\'s trusted pharmacy export marketplace. Compare '
                          'export prices, request quotations and order with '
                          'secure payment - delivered worldwide.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.6,
                              color: AppColors.darkBandMuted),
                        ),
                      ],
                    ),
                  ),
                  _footerColumn('Quick Links', [
                    ('Login', widget.onLogin),
                    ('Create Account', widget.onSignup),
                    ('Browse Medicines', _browse),
                  ]),
                  _footerColumn('Categories', [
                    for (final (name, _) in _categories) (name, _browse),
                  ]),
                  _footerColumn('Contact Us', [
                    ('Nagpur, Maharashtra, India', null),
                    (_phone, null),
                    ('support@medigram.com', null),
                  ]),
                ],
              ),
              const SizedBox(height: 26),
              Divider(color: Colors.white.withValues(alpha: 0.14)),
              const SizedBox(height: 12),
              Text(
                '(c) 2026 MediGram. All rights reserved.  |  Export orders are '
                'processed per contract after confirmation.',
                style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerColumn(String title, List<(String, VoidCallback?)> links) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Asap',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 12),
          for (final (label, onTap) in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: onTap,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.darkBandMuted)),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Shared helpers
  // ------------------------------------------------------------------

  Widget _sectionHeader(String overline, String title, String sub) {
    return Column(
      children: [
        Text(overline,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w800,
                color: AppColors.blueDark)),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Asap',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, height: 1.6, color: AppColors.textMuted)),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x141D82BF),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}