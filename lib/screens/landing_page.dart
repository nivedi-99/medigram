import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/region_picker.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/whatsapp_chat_button.dart';

/// Public marketing landing page - MedsBharat-style storefront shown to
/// signed-out visitors. Includes the region selector in the top bar.
class LandingPage extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const LandingPage({super.key, required this.onLogin, required this.onSignup});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const _phone = '+91 95884 23570';

  static const _categories = <(String, IconData)>[
    ('''Women's Personal Use''', Icons.health_and_safety_rounded),
    ('ED Medicines', Icons.medication_rounded),
    ('Anti-Anxiety', Icons.self_improvement_rounded),
    ('Pain Killers', Icons.healing_rounded),
  ];

  static const _offers = <(String, String, String)>[
    ('Flat 20% OFF', 'On your first export order', 'FIRST20'),
    ('Free Quotation', 'Itemised quotes on WhatsApp', 'QUOTE'),
    ('Bulk Pricing', 'Extra discounts on volume', 'BULK5'),
  ];

  static const _perks = <(IconData, String, String)>[
    (Icons.verified_rounded, '100% Genuine',
        'Certified products sourced from licensed manufacturers'),
    (Icons.local_shipping_rounded, 'Fast Dispatch',
        'Worldwide export shipping with full documentation'),
    (Icons.currency_exchange_rounded, 'Best Export Prices',
        'Direct-from-India pricing with volume discounts'),
    (Icons.support_agent_rounded, '24/7 Support',
        'Our trade desk is available around the clock'),
  ];

  static const _whyUs = <(IconData, String, String)>[
    (Icons.verified_user_rounded, '100% Genuine Products',
        'All medicines are sourced directly from authorised\ndistributors and manufacturers.'),
    (Icons.public_rounded, 'Pan-World Delivery',
        'We serve importers worldwide - get your orders\ndelivered right at your doorstep.'),
    (Icons.support_agent_rounded, '24/7 Support',
        'Our customer support team is available round\nthe clock to assist with your queries.'),
  ];

  void _requireLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login to browse the live export catalogue.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(),
            _header(),
            _categoryNav(),
            _hero(context),
            _perksStrip(),
            _offersStrip(),
            _categoriesSection(context),
            _whyUsSection(),
            _footer(context),
          ],
        ),
      ),
      floatingActionButton: const WhatsAppChatButton(),
    );
  }

  /// Sand utility bar with the region selector - the palette's beach accent.
  Widget _topBar() {
    return Container(
      color: AppColors.sand,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.place_rounded, size: 16, color: AppColors.onSand),
              const SizedBox(width: 6),
              Text(
                'Deliver to:',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSand),
              ),
              const SizedBox(width: 8),
              const RegionPicker(),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export Enquiries  |  Hope Pharma: $_phone',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSand),
              ),
              const SizedBox(width: 10),
              IconTheme(
                data: IconThemeData(color: AppColors.onSand),
                child: const ThemeToggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// White header with brand + auth buttons.
  Widget _header() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.blueGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_pharmacy_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MediGram',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                  Text(
                    'Global Pharmacy Exports',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: widget.onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blueDark,
                  foregroundColor: AppColors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Login'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onSignup,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blueDark,
                  side: BorderSide(color: AppColors.blueDark, width: 1.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                label: const Text('Register'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Category pill navigation.
  Widget _categoryNav() {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (label, _) in _categories)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ActionChip(
                  label: Text(label,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  backgroundColor: AppColors.bg,
                  side: BorderSide(color: AppColors.border),
                  onPressed: _requireLogin,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Green gradient hero with headline and CTAs.
  Widget _hero(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'India\'s Most Trusted Online Pharmacy Exports',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Order genuine Indian medicines at export prices and get them '
            'delivered anywhere in the world. Add products to your cart, '
            'pay securely or ask for a quotation - we take care of the rest.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14.5,
                color: Colors.white.withValues(alpha: 0.94),
                height: 1.5),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _requireLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.blueDark,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                ),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Browse Medicines',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                onPressed: widget.onSignup,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 14),
                ),
                icon: const Icon(Icons.person_rounded, size: 18),
                label: const Text('Create Account',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Four-perk strip under the hero.
  Widget _perksStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (icon, title, note) in _perks)
            SizedBox(
              width: 260,
              child: SoftCard(
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.blueDark, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.textDark)),
                          const SizedBox(height: 2),
                          Text(note,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Offer coupon strip.
  Widget _offersStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (title, note, code) in _offers)
            SizedBox(
              width: 260,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.pinkLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.sandDeep.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_rounded,
                        color: AppColors.sandDeep, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.textDark)),
                          Text(note,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(code,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSand)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Shop-by-category tiles.
  Widget _categoriesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shop by Category',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (label, icon) in _categories)
                SizedBox(
                  width: 210,
                  child: SoftCard(
                    onTap: _requireLogin,
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              Icon(icon, color: AppColors.blueDark, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppColors.textDark)),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Why-choose three-column section.
  Widget _whyUsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why Choose MediGram?',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (icon, title, note) in _whyUs)
                SizedBox(
                  width: 320,
                  child: SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 46,
                          width: 46,
                          decoration: BoxDecoration(
                            color: AppColors.blueLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              Icon(icon, color: AppColors.blueDark, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.textDark)),
                        const SizedBox(height: 6),
                        Text(note,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dark footer with quick links and contact.
  Widget _footer(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      color: AppColors.isDark ? AppColors.card : AppColors.deepTeal,
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 26),
      child: Wrap(
        spacing: 40,
        runSpacing: 26,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 300,
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
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'India\'s trusted pharmacy export marketplace. Compare '
                  'export prices, add to cart, pay securely or request a '
                  'quotation - delivered worldwide.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12.5,
                      height: 1.5),
                ),
              ],
            ),
          ),
          _footerColumn('Quick Links', [
            ('Login', widget.onLogin),
            ('Create Account', widget.onSignup),
            ('Browse Medicines', _requireLogin),
          ]),
          _footerColumn('Categories', [
            ('Women\'s Personal Use', _requireLogin),
            ('ED Medicines', _requireLogin),
            ('Pain Killers', _requireLogin),
          ]),
          _footerColumn('Contact Us', [
            ('Nagpur, Maharashtra, India', null),
            (_phone, null),
            ('support@medigram.com', null),
          ]),
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(color: Colors.white.withValues(alpha: 0.14)),
                Text(
                  '© 2026 MediGram. All rights reserved.  |  Export '
                      'orders are processed per contract after confirmation.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerColumn(String title, List<(String, VoidCallback?)> links) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5)),
          const SizedBox(height: 10),
          for (final (label, onTap) in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: onTap,
                child: Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }
}
