import 'package:flutter/material.dart';

/// Global UI brightness for the palette (light / dark).
enum AppBrightness { light, dark }

/// MediGram design tokens — palette designed with gemini-3.6-flash.
///
/// Colors are brightness-aware: the theme toggle flips every getter app-wide.
class AppColors {
  AppColors._();

  /// Toggled by the theme controller; every color getter reads this.
  static final ValueNotifier<AppBrightness> brightness =
      ValueNotifier<AppBrightness>(AppBrightness.light);

  static bool get isDark => brightness.value == AppBrightness.dark;

  static Color get bg =>
      isDark ? const Color(0xFF0B1624) : const Color(0xFFF4F7F9);
  static Color get card =>
      isDark ? const Color(0xFF132235) : const Color(0xFFFFFFFF);
  static Color get textDark =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0A192F);
  static Color get textMuted =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  static Color get border =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  /// Primary — deep teal-navy in light mode, bright cyan on dark surfaces.
  static Color get blueDark =>
      isDark ? const Color(0xFF00A3C4) : const Color(0xFF003B5C);
  static Color get blueMid =>
      isDark ? const Color(0xFF0088B2) : const Color(0xFF00668A);
  static Color get blueLight =>
      isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0F2FE);

  /// Accent — soft coral.
  static Color get pink =>
      isDark ? const Color(0xFFFF7A7A) : const Color(0xFFF46A6A);
  static Color get pinkLight =>
      isDark ? const Color(0xFF3D1C24) : const Color(0xFFFFEBEB);

  static Color get success =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
  static Color get warning =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  static Color get danger =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  /// Button label color on primary fills.
  static Color get onPrimary =>
      isDark ? const Color(0xFF06121F) : const Color(0xFFFFFFFF);

  static LinearGradient get heroGradient => LinearGradient(
        colors: [const Color(0xFF004B6E), const Color(0xFF0A7EA4), pink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get blueGradient => LinearGradient(
        colors: isDark
            ? [const Color(0xFF005C7A), const Color(0xFF00A3C4)]
            : [const Color(0xFF003B5C), const Color(0xFF007A8C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get pinkGradient => LinearGradient(
        colors: isDark
            ? [const Color(0xFFFF6B6B), const Color(0xFFFF9E9E)]
            : [const Color(0xFFF46A6A), const Color(0xFFFF8E8E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Auth/hero header gradient (three-stop for depth).
  static LinearGradient get authGradient => LinearGradient(
        colors: isDark
            ? [const Color(0xFF005C7A), const Color(0xFF00A3C4), pink]
            : [const Color(0xFF004B6E), const Color(0xFF0A7EA4), pink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Soft card shadow color.
  static Color get shadow =>
      isDark ? const Color(0xFF000000) : const Color(0xFF0A192F);
}
