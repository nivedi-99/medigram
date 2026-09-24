import 'package:flutter/material.dart';

/// Global UI brightness for the palette (light / dark).
enum AppBrightness { light, dark }

/// MediGram design tokens - "Ocean & Sand" palette.
///
/// Deep ocean teal primary, dark-teal/emerald gradients, seafoam tints and a
/// soft sand-yellow highlight. Colors are brightness-aware: the theme toggle
/// flips every getter app-wide.
class AppColors {
  AppColors._();

  // ---- Palette swatches --------------------------------------------------
  /// Deep ocean water - primary brand ink.
  static const Color deepTeal = Color(0xFF05353F);

  /// Shore break - secondary teal.
  static const Color darkTeal = Color(0xFF0A6C5E);

  /// Jade water - vivid accent.
  static const Color emerald = Color(0xFF0CA678);

  /// Foam green - soft highlight.
  static const Color seafoam = Color(0xFF63BC98);

  /// Dry sand - warm highlight; pair with [onSand] for text.
  static const Color sand = Color(0xFFEDDC82);

  /// Toggled by the theme controller; every color getter reads this.
  static final ValueNotifier<AppBrightness> brightness =
      ValueNotifier<AppBrightness>(AppBrightness.light);

  static bool get isDark => brightness.value == AppBrightness.dark;

  static Color get bg =>
      isDark ? const Color(0xFF04262C) : const Color(0xFFF4F8F6);
  static Color get card =>
      isDark ? const Color(0xFF0A343B) : const Color(0xFFFFFFFF);
  static Color get textDark => isDark ? const Color(0xFFEAF5F1) : deepTeal;
  static Color get textMuted =>
      isDark ? const Color(0xFF8FB3AA) : const Color(0xFF5C7A72);
  static Color get border =>
      isDark ? const Color(0xFF155057) : const Color(0xFFDDE9E4);

  /// Primary - deep ocean teal (seafoam in dark mode).
  static Color get blueDark => isDark ? seafoam : deepTeal;

  /// Secondary teal used for seeds and gradients.
  static Color get blueMid => isDark ? emerald : darkTeal;

  /// Soft tint behind primary icon chips.
  static Color get blueLight =>
      isDark ? const Color(0xFF0F4046) : const Color(0xFFE1F1EA);

  /// Accent - emerald; safe under white labels and badges.
  static Color get pink => isDark ? const Color(0xFF2FD3A5) : emerald;

  /// Pale sand tint behind accent chips and offer cards.
  static Color get pinkLight =>
      isDark ? const Color(0xFF33301A) : const Color(0xFFFBF6DE);

  /// Deep gold for icons and borders on [pinkLight]/sand surfaces.
  static Color get sandDeep =>
      isDark ? const Color(0xFFD9BC4A) : const Color(0xFFB9971F);

  /// Text/icon color on [sand] surfaces (sand is always light).
  static Color get onSand => deepTeal;

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
            : const [deepTeal, darkTeal, emerald],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get blueGradient => const LinearGradient(
        colors: [darkTeal, emerald],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get pinkGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF0E8A68), darkTeal]
            : const [emerald, darkTeal],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Auth/hero header gradient (three-stop for depth).
  static LinearGradient get authGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF03333B), Color(0xFF05454E), darkTeal]
            : const [deepTeal, darkTeal, emerald],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft card shadow color (teal-tinted in light mode).
  static Color get shadow => isDark ? const Color(0xFF000000) : deepTeal;
}