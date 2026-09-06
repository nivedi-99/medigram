import 'package:flutter/material.dart';

import '../services/theme_controller.dart';

/// Sun/moon quick toggle bound to the global theme controller.
class ThemeToggle extends StatelessWidget {
  final double size;

  const ThemeToggle({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => IconButton(
        tooltip:
            mode == ThemeMode.dark ? 'Switch to light mode' : 'Switch to dark mode',
        onPressed: () => ThemeController.set(
            mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
        icon: Icon(
          mode == ThemeMode.dark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          size: size,
        ),
      ),
    );
  }
}
