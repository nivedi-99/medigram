import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// Persists and applies the user's theme preference (light / dark / system).
/// Also keeps [AppColors.brightness] in sync so design tokens flip app-wide.
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'mg_theme_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final value = switch (stored) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    apply(value);
  }

  static Future<void> set(ThemeMode value) async {
    apply(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.name);
  }

  static void apply(ThemeMode value) {
    mode.value = value;
    AppColors.brightness.value =
        value == ThemeMode.dark ? AppBrightness.dark : AppBrightness.light;
  }
}
