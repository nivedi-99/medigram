import 'package:flutter/material.dart';

import '../services/currency_service.dart';
import '../theme/app_colors.dart';

/// Compact region selector for page headers (records the buyer's region for
/// context). Displayed prices and payments are always in INR via
/// [CurrencyService].
class RegionPicker extends StatelessWidget {
  const RegionPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyService.region,
      builder: (context, _, __) {
        final current = CurrencyService.regionCountryName;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: CurrencyService.regions
                      .any((r) => r.country == current)
                  ? current
                  : 'United States',
              items: [
                for (final r in CurrencyService.regions)
                  DropdownMenuItem(
                    value: r.country,
                    child: Text(
                      r.country,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark),
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) CurrencyService.setRegion(v);
              },
              icon: const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.textMuted),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }
}