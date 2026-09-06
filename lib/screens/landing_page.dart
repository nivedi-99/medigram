import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/app_colors.dart';

/// Public marketing landing page — shown to signed-out visitors.
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
          'last-mile delivery to licensed pharmacies — all tracked from a '
          'single dashboard.',
      'assets/landing/supply-chain-3d.jpg',
    ),
    (
      'Live order intelligence',
      'Every export order surfaces in a live operations view — statuses, '
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
    final content = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _heroText(context)),
              const SizedBox(width: 48),
              Expanded(child: _heroImage()),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroText(context),
              const SizedBox(height: 32),
              _heroImage(),
            ],
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.blueLight.withValues(alpha: 0.6),
                AppColors.bg,
                AppColors.bg,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -60,
                child:
                    _heroBlob(220, AppColors.blueMid.withValues(alpha: 0.08)),
              ),
              Positioned(
                bottom: -90,
                left: -40,
                child: _heroBlob(240, AppColors.pink.withValues(alpha: 0.07)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: wide ? 48 : 22, vertical: wide ? 56 : 36),
                child: content,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroText(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    final headline = wide ? 52.0 : 34.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.blueMid.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 15, color: AppColors.blueMid),
              const SizedBox(width: 6),
              Text(
                'WHO-GMP CERTIFIED SUPPLY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                  color: AppColors.blueDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Pharmaceutical exports,',
          style: TextStyle(
            fontSize: headline,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: AppColors.textDark,
          ),
        ),
        Text(
          'delivered with certainty.',
          style: TextStyle(
            fontSize: headline,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: AppColors.blueMid,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'MediGram connects licensed pharmacies and distributors to a verified '
                'global supply chain — 180+ products, KYC-verified partners and '
                'every shipment tracked to the door.',
            style: TextStyle(
              fontSize: 16.5,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: onSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blueDark,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              ),
              child: const Text('Create a business account'),
            ),
            OutlinedButton(
              onPressed: onLogin,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blueDark,
                side:
                    BorderSide(color: AppColors.blueMid.withValues(alpha: 0.5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _heroProof('180+ catalogue products'),
            _heroProof('KYC-verified buyers'),
            _heroProof('Door-tracked shipments'),
          ],
        ),
      ],
    );
  }
  Widget _heroProof(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _heroBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
  Widget _heroImage() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueMid.withValues(alpha: 0.28),
            blurRadius: 60,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: const _LandingImage(
        asset: 'assets/landing/hero-3d.jpg',
        aspectRatio: 1584 / 672,
        radius: 28,
      ),
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
                    'MediGram — Global Pharmaceutical Exports',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
              Text(
                '© 2026 MediGram. All rights reserved.',
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

  final double radius;

  const _LandingImage(
      {required this.asset, required this.aspectRatio, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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
