import 'package:flutter/material.dart';

/// A pharmacy pill bottle drawn entirely in Flutter (no image assets needed).
///
/// The bottle — cap, neck and body — carries a paper label with the
/// medicine name printed on it, plus an optional sub line (generic /
/// manufacturer) and footer line (packing / MOQ). Every medicine gets its
/// own bottle colour, chosen deterministically from its name.
class MedicineBottleLabel extends StatelessWidget {
  final String medicineName;
  final String? subtitle;
  final String? footer;
  final double width;
  final double height;

  const MedicineBottleLabel({
    super.key,
    required this.medicineName,
    this.subtitle,
    this.footer,
    this.width = 120,
    this.height = 170,
  });

  /// Stable hash (unlike [String.hashCode], this is guaranteed to produce the
  /// same value across sessions) used to pick a bottle colour per medicine.
  static int _stableHash(String value) {
    var h = 0;
    for (final unit in value.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }

  /// Amber / blue / teal / violet / rose / green pill-bottle plastics,
  /// each as a [top, bottom] gradient pair.
  static const List<List<Color>> _bodies = [
    [Color(0xFFE08A2E), Color(0xFFB45309)],
    [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    [Color(0xFF14B8A6), Color(0xFF0F766E)],
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    [Color(0xFFEC4899), Color(0xFFBE185D)],
    [Color(0xFF22C55E), Color(0xFF15803D)],
  ];

  List<Color> get _gradient =>
      _bodies[_stableHash(medicineName) % _bodies.length];

  /// Name font size adapts to length so long medicine names still fit the
  /// label cleanly (3 lines max, then ellipsis).
  double get _nameFontSize {
    final len = medicineName.length;
    if (len > 22) return 10.5;
    if (len > 15) return 12;
    return 14;
  }

  @override
  Widget build(BuildContext context) {
    final capTop = _gradient.last;
    final capBottom = _gradient.first;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        children: [
          // --- Child-resistant cap with grip ridges ---
          Container(
            height: height * 0.15,
            width: width * 0.70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [capTop, capBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
                bottom: Radius.circular(3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (_) => Container(
                  width: 1.6,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black26,
                ),
              ),
            ),
          ),
          // --- Neck ---
          Container(
            height: height * 0.05,
            width: width * 0.46,
            color: capBottom.withValues(alpha: 0.9),
          ),
          // --- Body with the wrapped paper label ---
          Expanded(
            child: Container(
              width: width * 0.92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_gradient.first, _gradient.last],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(16),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29142A3B),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.06,
                vertical: height * 0.05,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEF8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Column(
                  children: [
                    // Brand strip at the top of the label.
                    Text(
                      'MEDIGRAM',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 7,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.2,
                        color: _gradient.last,
                      ),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black12,
                    ),
                    // The medicine name — the whole point of the label.
                    Expanded(
                      child: Center(
                        child: Text(
                          medicineName,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _nameFontSize,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    if (footer != null && footer!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          footer!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 7.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }
}
