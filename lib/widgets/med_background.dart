import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One floating medicine motif drawn in fractional coordinates so it works
/// on any canvas size.
///
/// Kind: 0 = capsule, 1 = tablet, 2 = medical cross.
class _Motif {
  final int kind;
  final double fx; // 0..1 horizontal anchor
  final double size; // base size in px
  final double speed; // upward drift multiplier
  final double phase; // 0..1 loop offset
  final double tilt; // base rotation (radians)
  final double alpha; // stroke/fill opacity

  const _Motif(this.kind, this.fx, this.size, this.speed, this.phase,
      this.tilt, this.alpha);
}

/// Animated medicine-themed background VFX.
///
/// Paints (in order): an optional base canvas color, two soft teal "aura"
/// blobs that slowly breathe, then capsules, tablets and medical crosses
/// drifting gently upward with a sine sway — the classic modern pharmacy
/// ambience, pure CustomPainter so it stays cheap on web.
class MedBackgroundVfx extends StatefulWidget {
  /// Canvas color painted beneath the VFX (e.g. the page background).
  final Color? baseColor;

  /// Foreground widget laid above the VFX.
  final Widget? child;

  const MedBackgroundVfx({
    super.key,
    this.baseColor,
    this.child,
  });

  @override
  State<MedBackgroundVfx> createState() => _MedBackgroundVfxState();
}

class _MedBackgroundVfxState extends State<MedBackgroundVfx>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))
        ..repeat();

  static final List<_Motif> _motifs = _buildMotifs();

  static List<_Motif> _buildMotifs() {
    final rng = math.Random(7);
    return List.generate(16, (i) {
      return _Motif(
        i % 3,
        rng.nextDouble(),
        12 + rng.nextDouble() * 26,
        0.5 + rng.nextDouble(),
        rng.nextDouble(),
        (rng.nextDouble() - 0.5) * 0.9,
        0.05 + rng.nextDouble() * 0.06,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _MedVfxPainter(
          _controller.value,
          motifs: _motifs,
          baseColor: widget.baseColor,
          isDark: AppColors.isDark,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _MedVfxPainter extends CustomPainter {
  final double t;
  final List<_Motif> motifs;
  final Color? baseColor;
  final bool isDark;

  _MedVfxPainter(
    this.t, {
    required this.motifs,
    required this.baseColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (baseColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = baseColor!);
    }

    final Color tint = isDark ? Colors.white : AppColors.brandTeal;
    final double auraAlpha = isDark ? 0.05 : 0.07;

    // Breathing teal auras.
    final aura = Paint()
      ..isAntiAlias = true
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60)
      ..color = tint.withValues(alpha: auraAlpha);
    const auraSpecs = [(0.12, 0.16, 0.34), (0.86, 0.78, 0.30), (0.50, 1.04, 0.26)];
    for (final (fx, fy, fr) in auraSpecs) {
      final cx = size.width * fx +
          math.sin(t * 2 * math.pi + fx * 9) * size.width * 0.02;
      final cy = size.height * fy +
          math.cos(t * 2 * math.pi + fy * 7) * size.height * 0.015;
      canvas.drawCircle(Offset(cx, cy), size.shortestSide * fr, aura);
    }

    // Drifting medicine motifs.
    for (final m in motifs) {
      final span = size.height + m.size * 2;
      final y = span - ((t * m.speed + m.phase) % 1) * span - m.size;
      final x = size.width * m.fx +
          math.sin(t * 2 * math.pi + m.phase * 6.28) * 14;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(m.tilt + math.sin(t * 2 * math.pi + m.phase * 3) * 0.08);

      final paint = Paint()
        ..isAntiAlias = true
        ..color = tint.withValues(alpha: m.alpha * (isDark ? 1.4 : 1.0));
      switch (m.kind) {
        case 0:
          _drawCapsule(canvas, m.size, paint);
          break;
        case 1:
          _drawTablet(canvas, m.size, paint);
          break;
        default:
          _drawCross(canvas, m.size, paint);
      }
      canvas.restore();
    }
  }

  void _drawCapsule(Canvas c, double s, Paint p) {
    final w = s * 1.9;
    final h = s * 0.8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Radius.circular(h / 2),
    );
    c.drawRRect(rect, p);
    // Divider + highlight for the two-tone pill look.
    final divider = Paint()
      ..color = p.color.withValues(alpha: p.color.a / 3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    c.drawLine(Offset(0, -h / 2), Offset(0, h / 2), divider);
  }

  void _drawTablet(Canvas c, double s, Paint p) {
    c.drawCircle(Offset.zero, s * 0.55, p);
    final ring = Paint()
      ..color = p.color.withValues(alpha: p.color.a / 3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    c.drawCircle(Offset.zero, s * 0.3, ring);
  }

  void _drawCross(Canvas c, double s, Paint p) {
    final arm = s * 0.72;
    final thick = s * 0.3;
    final r = Radius.circular(thick * 0.35);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: arm, height: thick), r),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: thick, height: arm), r),
      p,
    );
  }

  @override
  bool shouldRepaint(_MedVfxPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.isDark != isDark ||
      oldDelegate.baseColor != baseColor;
}
