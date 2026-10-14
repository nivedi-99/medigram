import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_config.dart';
import '../theme/app_colors.dart';

/// Product photo with a hardened fallback chain (web-safe):
///
/// 1. same-origin proxy  `/api/v1/uploads/product-photo/<id>` (no CORS)
/// 2. stored storage URL (image_url / canonical path from the API)
/// 3. bundled label shot   assets/products/labels/<name>.png
/// 4. bundled category shot assets/products/<category>.jpg
/// 5. soft medication-icon tile
///
/// Network hops show a spinner and log failures so broken URLs are visible.
class ProductPhoto extends StatefulWidget {
  final ProductRecord product;
  final BoxFit fit;

  const ProductPhoto({
    super.key,
    required this.product,
    this.fit = BoxFit.cover,
  });

  @override
  State<ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<ProductPhoto> {
  late List<String> _sources;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant ProductPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.imageUrl != widget.product.imageUrl) {
      _rebuild();
    }
  }

  void _rebuild() {
    _sources = [
      // 0. Same-origin image route (Vercel rewrite proxies the storage
      //    object): immune to client-side DNS/CORS problems with
      //    *.supabase.co hosts.
      if (widget.product.hasPhoto) '/product-img/${widget.product.id}',
      // 1. Render API proxy (public route, web/CORS-safe).
      if (widget.product.hasPhoto)
        ApiConfig.uri('/uploads/product-photo/${widget.product.id}')
            .toString(),
      // 2. Stored/canonical storage URL from the API payload.
      if (widget.product.imageUrl.isNotEmpty) widget.product.imageUrl,
      // 3/4. Bundled label + category shots (may be absent in the bundle).
      'assets/products/labels/${_slug(widget.product.name)}.png',
      widget.product.imageAsset,
    ];
    _stage = 0;
  }

  void _advance() {
    if (!mounted) return;
    debugPrint(
        'ProductPhoto: "${_sources[_stage]}" failed for ${widget.product.name}');
    setState(() => _stage += 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage >= _sources.length) return _iconTile();
    final String src = _sources[_stage];
    final bool isAsset = src.startsWith('assets/');
    return isAsset
        ? Image.asset(
            src,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => _iconTile(),
          )
        : Image.network(
            src,
            fit: widget.fit,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _tile(),
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _advance());
              return _tile();
            },
          );
  }

  Widget _tile({Widget? child}) {
    return Container(
      color: AppColors.blueLight.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: child ??= Icon(
        Icons.medication_rounded,
        size: 34,
        color: AppColors.blueMid.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _iconTile() => _tile();

  /// Mirrors the asset slug convention used by the generated bottle labels.
  static String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
