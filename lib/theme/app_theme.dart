import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the app theme. The whole app renders the light "Medina" look —
/// white surfaces, slate text and a sky-blue accent — in both theme modes.
/// Headings use Asap, body copy uses Lato (loaded via Google Fonts in
/// web/index.html).
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blueMid,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Lato',
  );

  const TextStyle heading = TextStyle(
      fontFamily: 'Asap', color: AppColors.textDark, fontWeight: FontWeight.w700);

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: heading.copyWith(fontSize: 40, height: 1.15),
      displayMedium: heading.copyWith(fontSize: 34, height: 1.15),
      displaySmall: heading.copyWith(fontSize: 28, height: 1.2),
      headlineLarge: heading.copyWith(fontSize: 26),
      headlineMedium: heading.copyWith(fontSize: 22),
      headlineSmall: heading.copyWith(fontSize: 19),
      titleLarge: heading.copyWith(fontSize: 17),
      titleMedium: heading.copyWith(fontSize: 15.5),
      titleSmall: heading.copyWith(fontSize: 13.5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.textDark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.blueLight,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? AppColors.blueDark : AppColors.textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.blueDark : AppColors.textMuted,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blueDark,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
            fontFamily: 'Asap', fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blueDark,
        side: const BorderSide(color: AppColors.blueDark, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.blueDark, width: 1.6),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
  );
}
