import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/app_colors.dart';

/// Public marketing landing page Ã¢â‚¬â€ shown to signed-out visitors.
class LandingPage extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const LandingPage({super.key, required this.onLogin, required this.onSignup});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  VoidCallback get onLogin => widget.onLogin;
  VoidCallback get onSignup => widget.onSignup;

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      // Warm the image cache so hero and section visuals pop in instantly.
      for (final asset in const [
        'assets/landing/hero-3d.jpg',
        'assets/landing/supply-chain-3d.jpg',
        'assets/landing/dashboard-3d.jpg',
        'assets/landing/kyc-shield-3d.jpg',
      ]) {
        precacheImage(NetworkImage(asset), context);
      }
    }
  }

  static const _sections = [
    (
      'From factory to pharmacy',
      'One verified pipeline: manufacturer QA, air and sea freight, and '
          'last-mile delivery to licensed pharmacies Ã¢â‚¬â€ all tracked from a '
          'single dashboard.',
      'assets/landing/supply-chain-3d.jpg',
    ),
    (
      'Live order intelligence',
      'Every export order surfaces in a live operations view Ã¢â‚¬â€ statuses, '
          'Incoterms, documents and shipment milestones, without a single '
          'email thread.',
      'assets/landing/dashboard-3d.jpg',
    ),
    (
      'KYC-verified trade',
      'Every buyer is identity- and licence-verified before their first '
          'order, so you trade only with trusted counterparties.',
      'assets/landing/kyc-shield-3d.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNav(context),
            _buildHero(context),
            _buildStatsBand(context),
            for (final (title, body, image) in _sections)
              _buildImageSection(context, title, body, image),
            _buildCategoriesBand(context),
            _buildCta(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_pharmacy_rounded, color: AppColors.blueDark, size: 26),
          const SizedBox(width: 8),
          Text(
            'MediGram',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.textDark,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: () => ThemeController.set(
                AppColors.isDark ? ThemeMode.light : ThemeMode.dark),
            icon: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) => Icon(
                mode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(onPressed: onLogin, child: const Text('Sign in')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueDark,
              foregroundColor: AppColors.onPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            child: const Text('Get started'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: wide
          ? Row(
              children: [
                Expanded(child: _heroText(context)),
                const SizedBox(width: 32),
                Expanded(child: _heroImage()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heroText(context),
                const SizedBox(height: 24),
                _heroImage(),
              ],
            ),
    );
  }

  Widget _heroText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.blueLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.blueMid.withValues(alpha: 0.4)),
          ),
          child: Text(
            'WHO-GMP CERTIFIED SUPPLY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
              color: AppColors.blueDark,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Pharmaceutical exports,\ndelivered with certainty.',
          style: TextStyle(
            fontSize: 40,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MediGram connects licensed pharmacies and distributors to a verified '
          'global supply chain Ã¢â‚¬â€ 180+ products, KYC-verified partners and '
          'every shipment tracked to the door.',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: onSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blueDark,
                foregroundColor: AppColors.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              ),
              child: const Text('Create a business account'),
            ),
            OutlinedButton(
              onPressed: onLogin,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroImage() {
    return const _LandingImage(
      asset: 'assets/landing/hero-3d.jpg',
      aspectRatio: 1584 / 672,
    );
  }

  Widget _buildStatsBand(BuildContext context) {
    final stats = [
      ('180+', 'Catalogue products'),
      ('14', 'Therapy categories'),
      ('WHO-GMP', 'Certified manufacturing'),
      ('24h', 'KYC verification'),
    ];
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 18,
        children: [
          for (final (value, label) in stats)
            Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blueDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  // __LANDING_TAIL__

  Widget _buildImageSection(
      BuildContext context, String title, String body, String image) {
    final wide = MediaQuery.of(context).size.width > 900;
    final visual = _LandingImage(asset: image, aspectRatio: 1408 / 768);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: TextStyle(
            fontSize: 15.5,
            height: 1.55,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: wide
          ? Row(
              children: [
                Expanded(child: visual),
                const SizedBox(width: 40),
                Expanded(child: text),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 20), visual],
            ),
    );
  }
  // __LANDING_TAIL2__

  Widget _buildCategoriesBand(BuildContext context) {
    final cats = [
      ('Anti Parasites', Icons.medication_rounded),
      ('Ed Medicines', Icons.favorite_rounded),
      ('Anti-Biotics', Icons.science_rounded),
      ('Pain Killers', Icons.healing_rounded),
      ('Anti-Anxiety', Icons.spa_rounded),
      ('Hair Care', Icons.content_cut_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Text(
            'Every therapy area, one catalogue',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final (name, icon) in cats)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: AppColors.blueMid),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 44),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            'Start sourcing with certainty today.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create your verified business account in under two minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onSignup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.blueDark,
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
            ),
            child: const Text(
              'Create a business account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_pharmacy_rounded,
                      size: 18, color: AppColors.blueMid),
                  const SizedBox(width: 6),
                  Text(
                    'MediGram Ã¢â‚¬â€ Global Pharmaceutical Exports',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
              Text(
                'Ã‚Â© 2026 MediGram. All rights reserved.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bounded, fade-in landing visual with progress and graceful error state.
class _LandingImage extends StatelessWidget {
  final String asset;
  final double aspectRatio;

  const _LandingImage({required this.asset, required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.network(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          gaplessPlayback: true,
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
              color: AppColors.blueLight.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.blueLight.withValues(alpha: 0.4),
            alignment: Alignment.center,
            child: Icon(
              Icons.image_not_supported_rounded,
              size: 42,
              color: AppColors.blueMid,
            ),
          ),
        ),
      ),
    );
  }
}
