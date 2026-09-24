import 'package:flutter/material.dart';

/// Global UI brightness for the palette (light / dark).
enum AppBrightness { light, dark }

/// MediGram design tokens - MedsBharat storefront palette.
///
/// Green primary (green-600 family), orange accents for offers, white
/// surfaces on gray-50. Colors are brightness-aware: the theme toggle
/// flips every getter app-wide.
class AppColors {
  AppColors._();

  /// Toggled by the theme controller; every color getter reads this.
  static final ValueNotifier<AppBrightness> brightness =
      ValueNotifier<AppBrightness>(AppBrightness.light);

  static bool get isDark => brightness.value == AppBrightness.dark;

  static Color get bg =>
      isDark ? const Color(0xFF0B1220) : const Color(0xFFF9FAFB);
  static Color get card =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFFFFFF);
  static Color get textDark =>
      isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827);
  static Color get textMuted =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);
  static Color get border =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

  /// Primary - pharmacy green (MedsBharat green-700/500).
  static Color get blueDark =>
      isDark ? const Color(0xFF22C55E) : const Color(0xFF15803D);
  static Color get blueMid =>
      isDark ? const Color(0xFF16A34A) : const Color(0xFF16A34A);
  static Color get blueLight =>
      isDark ? const Color(0xFF14301F) : const Color(0xFFDCFCE7);

  /// Accent - offers orange (orange-500 family).
  static Color get pink =>
      isDark ? const Color(0xFFFB923C) : const Color(0xFFF97316);
  static Color get pinkLight =>
      isDark ? const Color(0xFF3B2A14) : const Color(0xFFFFF7ED);

  static Color get success =>
      isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
  static Color get warning =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFF97316);
  static Color get danger =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  /// Button label color on primary fills.
  static Color get onPrimary =>
      isDark ? const Color(0xFF052E16) : const Color(0xFFFFFFFF);

  static LinearGradient get heroGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF166534), Color(0xFF15803D), Color(0xFF16A34A)]
            : const [Color(0xFF15803D), Color(0xFF16A34A), Color(0xFF22C55E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get blueGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF14532D), Color(0xFF16A34A)]
            : const [Color(0xFF15803D), Color(0xFF22C55E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get pinkGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFFEA580C), Color(0xFFF97316)]
            : const [Color(0xFFF97316), Color(0xFFFB923C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Auth/hero header gradient (three-stop for depth).
  static LinearGradient get authGradient => LinearGradient(
        colors: isDark
            ? const [Color(0xFF166534), Color(0xFF15803D), Color(0xFF16A34A)]
            : const [Color(0xFF15803D), Color(0xFF16A34A), Color(0xFF22C55E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft card shadow color.
  static Color get shadow =>
      isDark ? const Color(0xFF000000) : const Color(0xFF111827);
}
