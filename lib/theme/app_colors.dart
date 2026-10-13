import 'package:flutter/material.dart';

/// Global UI brightness for the palette (light / dark).
enum AppBrightness { light, dark }

/// MediGram design tokens - "Cream & Healing Teal" palette.
///
/// A warm cream canvas (#FFFDD7) paired with a healing teal brand
/// (#539692) and a deep-teal ink for text. Colors are brightness-aware:
/// the theme toggle flips every getter app-wide (dark mode keeps the
/// deep-teal night palette).
class AppColors {
  AppColors._();

  // ---- Palette swatches --------------------------------------------------
  /// Brand teal - primary actions, gradients and accents.
  static const Color brandTeal = Color(0xFF539692);

  /// Deep teal ink - headlines and body text on cream.
  static const Color tealDeep = Color(0xFF2F5E5B);

  /// Soft teal - gradient highlight stops.
  static const Color tealSoft = Color(0xFF6FB3AE);

  /// Warm cream canvas - the app-wide background.
  static const Color cream = Color(0xFFFFFDD7);

  /// Muted gold - pairs with cream surfaces for highlights.
  static const Color gold = Color(0xFFB9971F);

  /// Secondary teal (kept for dark-mode depth).
  static const Color darkTeal = Color(0xFF0A6C5E);

  /// Jade water - vivid success/accent tone.
  static const Color emerald = Color(0xFF0CA678);

  /// Foam green - soft highlight (dark mode).
  static const Color seafoam = Color(0xFF63BC98);

  /// Warm highlight surface; pairs with [onSand] for text.
  static const Color sand = Color(0xFFFFFDD7);

  /// Toggled by the theme controller; every color getter reads this.
  static final ValueNotifier<AppBrightness> brightness =
      ValueNotifier<AppBrightness>(AppBrightness.light);

  static bool get isDark => brightness.value == AppBrightness.dark;

  static Color get bg =>
      isDark ? const Color(0xFF04262C) : cream;
  static Color get card =>
      isDark ? const Color(0xFF0A343B) : const Color(0xFFFFFFFF);
  static Color get textDark => isDark ? const Color(0xFFEAF5F1) : tealDeep;
  static Color get textMuted =>
      isDark ? const Color(0xFF8FB3AA) : const Color(0xFF6C8680);
  static Color get border =>
      isDark ? const Color(0xFF155057) : const Color(0xFFEAE4C4);

  /// Primary - healing teal (seafoam in dark mode).
  static Color get blueDark => isDark ? seafoam : brandTeal;

  /// Secondary teal used for seeds and gradients.
  static Color get blueMid => isDark ? emerald : const Color(0xFF43837F);

  /// Soft tint behind primary icon chips.
  static Color get blueLight =>
      isDark ? const Color(0xFF0F4046) : const Color(0xFFE0EFEA);

  /// Accent - emerald; safe under white labels and badges.
  static Color get pink => isDark ? const Color(0xFF2FD3A5) : emerald;

  /// Pale sand tint behind accent chips and offer cards.
  static Color get pinkLight =>
      isDark ? const Color(0xFF33301A) : const Color(0xFFFBF6DE);

  /// Deep gold for icons and borders on [pinkLight]/sand surfaces.
  static Color get sandDeep => gold;

  /// Text/icon color on [sand] surfaces (sand is always light).
  static Color get onSand => tealDeep;

  static Color get success => isDark ? const Color(0xFF2FD3A5) : emerald;
  static Color get warning =>
      isDark ? const Color(0xFFFACC15) : const Color(0xFFC88906);
  static Color get danger =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  /// Button label color on primary fills.
  static Color get onPrimary =>
      isDark ? const Color(0xFF04262C) : const Color(0xFFFFFFFF);

  static LinearGradient get heroGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF03333B), Color(0xFF05454E), darkTeal]
            : const [tealDeep, brandTeal, tealSoft],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get blueGradient => const LinearGradient(
        colors: [brandTeal, tealDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get pinkGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF0E8A68), darkTeal]
            : const [Color(0xFF43837F), tealDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Auth/hero header gradient (three-stop for depth).
  static LinearGradient get authGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF03333B), Color(0xFF05454E), darkTeal]
            : const [Color(0xFF3B7370), brandTeal, tealSoft],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft card shadow color (teal-tinted in light mode).
  static Color get shadow => isDark ? const Color(0xFF000000) : tealDeep;
}