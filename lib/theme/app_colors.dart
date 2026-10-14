import 'package:flutter/material.dart';

/// Global UI brightness for the palette (light / dark).
enum AppBrightness { light, dark }

/// MediGram design tokens - unified "Deep Ocean" palette.
///
/// Every page shares the radiant deep-teal canvas (#04262C) with glowing
/// seafoam-teal primaries so product imagery pops. The theme toggle stays
/// for compatibility; both modes render this same luminous palette.
class AppColors {
  AppColors._();

  // ---- Palette swatches --------------------------------------------------
  /// Brand teal - primary actions, gradients and accents.
  static const Color brandTeal = Color(0xFF539692);

  /// Deep teal ink - accents on bright surfaces.
  static const Color tealDeep = Color(0xFF2F5E5B);

  /// Soft teal - gradient highlight stops.
  static const Color tealSoft = Color(0xFF6FB3AE);

  /// Warm cream (reserved accents; the canvas is deep teal).
  static const Color cream = Color(0xFFFFFDD7);

  /// Muted gold - pairs with teal for highlights.
  static const Color gold = Color(0xFFB9971F);

  /// Shore break - secondary teal.
  static const Color darkTeal = Color(0xFF0A6C5E);

  /// Jade water - vivid success/accent tone.
  static const Color emerald = Color(0xFF0CA678);

  /// Foam green - the glowing primary on the deep canvas.
  static const Color seafoam = Color(0xFF63BC98);

  /// Teal-tinted highlight surface (header strips, badges).
  static const Color sand = Color(0xFF0F4046);

  /// Toggled by the theme controller; kept for API compatibility.
  static final ValueNotifier<AppBrightness> brightness =
      ValueNotifier<AppBrightness>(AppBrightness.light);

  static bool get isDark => brightness.value == AppBrightness.dark;

  /// App-wide canvas - radiant deep ocean teal.
  static Color get bg => const Color(0xFF04262C);

  static Color get card => const Color(0xFF0A343B);
  static Color get textDark => const Color(0xFFEAF5F1);
  static Color get textMuted => const Color(0xFF8FB3AA);
  static Color get border => const Color(0xFF155057);

  /// Primary - glowing seafoam teal.
  static Color get blueDark => seafoam;

  /// Secondary teal used for seeds and gradients.
  static Color get blueMid => emerald;

  /// Soft tint behind primary icon chips.
  static Color get blueLight => const Color(0xFF0F4046);

  /// Accent - bright jade; safe under dark labels.
  static Color get pink => const Color(0xFF2FD3A5);

  /// Deep gold-tinted surface behind accent chips and offer cards.
  static Color get pinkLight => const Color(0xFF33301A);

  /// Bright gold for icons and borders on [pinkLight] surfaces.
  static Color get sandDeep => const Color(0xFFD9BC4A);

  /// Text/icon color on [sand] surfaces.
  static Color get onSand => const Color(0xFFEAF5F1);

  static Color get success => const Color(0xFF2FD3A5);
  static Color get warning => const Color(0xFFFACC15);
  static Color get danger => const Color(0xFFF87171);

  /// Button label color on primary fills.
  static Color get onPrimary => const Color(0xFF04262C);

  static LinearGradient get heroGradient => const LinearGradient(
        colors: [Color(0xFF03333B), Color(0xFF05454E), darkTeal],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get blueGradient => const LinearGradient(
        colors: [darkTeal, emerald],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get pinkGradient => const LinearGradient(
        colors: [Color(0xFF0E8A68), darkTeal],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Auth/hero header gradient (three-stop for depth).
  static LinearGradient get authGradient => const LinearGradient(
        colors: [Color(0xFF03333B), Color(0xFF05454E), darkTeal],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft card shadow color.
  static Color get shadow => const Color(0xFF000000);
}