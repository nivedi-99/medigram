import 'package:flutter/material.dart';

/// Global UI brightness for the palette (light / dark).
enum AppBrightness { light, dark }

/// MediGram design tokens - light "Medina" palette.
///
/// A clean medical-marketplace look: white surfaces, slate text, soft
/// light-gray section alternation and a sky-blue accent. The theme toggle
/// stays for compatibility; both modes render this same light palette.
/// Every token is a compile-time const so widgets can use it anywhere.
class AppColors {
  AppColors._();

  // ---- Palette swatches --------------------------------------------------
  /// Brand teal - soft accents and background VFX tint.
  static const Color brandTeal = Color(0xFF539692);

  /// Deep azure - strong accents on bright surfaces.
  static const Color tealDeep = Color(0xFF1F6E9C);

  /// Light sky - gradient highlight stops.
  static const Color tealSoft = Color(0xFF79CCF2);

  /// Warm cream (reserved accents).
  static const Color cream = Color(0xFFFFF6E3);

  /// Amber accent - highlights and ratings.
  static const Color gold = Color(0xFFF3A43D);

  /// Sky blue - secondary accent in gradients.
  static const Color darkTeal = Color(0xFF1D82BF);

  /// Azure - the app's primary accent.
  static const Color emerald = Color(0xFF2A93C9);

  /// Primary accent alias (sky blue).
  static const Color seafoam = Color(0xFF2A93C9);

  /// Pale blue highlight surface (header strips, badges).
  static const Color sand = Color(0xFFEAF4FB);

  /// Alternating section surface.
  static const Color surfaceAlt = Color(0xFFF5F5F5);

  /// Dark band - header/footer strips.
  static const Color darkBand = Color(0xFF191919);

  /// Muted text on [darkBand].
  static const Color darkBandMuted = Color(0xFFBDBDBD);

  /// Toggled by the theme controller; kept for API compatibility.
  static final ValueNotifier<AppBrightness> brightness =
      ValueNotifier<AppBrightness>(AppBrightness.light);

  static bool get isDark => brightness.value == AppBrightness.dark;

  /// App-wide canvas - soft light neutral so white cards read clearly.
  static const Color bg = Color(0xFFF7F9FA);

  static const Color card = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF434445);
  static const Color textMuted = Color(0xFF868686);
  static const Color border = Color(0xFFE5E5E5);

  /// Primary - sky blue.
  static const Color blueDark = emerald;

  /// Secondary blue used for seeds and gradients.
  static const Color blueMid = emerald;

  /// Soft tint behind primary icon chips.
  static const Color blueLight = Color(0xFFE3F2FB);

  /// Bright sky accent - icons and links.
  static const Color pink = Color(0xFF55BBEB);

  /// Pale blue surface behind accent chips and offer cards.
  static const Color pinkLight = Color(0xFFEAF6FE);

  /// Bright amber for icons and borders on [pinkLight] surfaces.
  static const Color sandDeep = Color(0xFFF3A43D);

  /// Text/icon color on [sand] surfaces.
  static const Color onSand = Color(0xFF1F5F86);

  static const Color success = Color(0xFF149A66);
  static const Color warning = Color(0xFFE5A50A);
  static const Color danger = Color(0xFFE5484D);

  /// Button label color on primary fills.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Hero banner - deep azure gradient (white text reads on it).
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF125E93), Color(0xFF1D82BF), Color(0xFF2A93C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [emerald, Color(0xFF55BBEB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFF1D82BF), Color(0xFF125E93)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Auth/hero header gradient (three-stop for depth).
  static const LinearGradient authGradient = heroGradient;

  /// Soft card shadow color.
  static const Color shadow = Color(0xFF000000);
}