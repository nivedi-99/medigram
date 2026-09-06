import 'package:flutter/material.dart';

/// Palette sourced from the provided "Blue and Pink Color Palette" swatch.
class AppColors {
  AppColors._();

  static const Color blueDark = Color(0xFF4E8BC4);
  static const Color blueMid = Color(0xFF96CBFC);
  static const Color blueLight = Color(0xFFC2E1FC);
  static const Color pinkLight = Color(0xFFFFC2D9);
  static const Color pink = Color(0xFFFF99BE);

  static const Color textDark = Color(0xFF122B45);
  static const Color textMuted = Color(0xFF7C8CA6);
  static const Color bg = Color(0xFFF7FAFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF3FB98B);
  static const Color warning = Color(0xFFE8A93A);
  static const Color danger = Color(0xFFE86B6B);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [blueDark, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [blueDark, blueMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [pink, pinkLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient authGradient = LinearGradient(
    colors: [blueDark, Color(0xFF6FA6D6), pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
