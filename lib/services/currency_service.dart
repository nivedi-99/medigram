import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display pricing for the MediGram catalogue.
///
/// * Prices are authored in USD. The header selector picks the display
///   region (US / UK / EU / India / Australia) and every displayed price
///   converts live using the admin-managed FX table (/api/v1/payments).
/// * Settlement is always collected in INR (₹) — see [settlementInr] and
///   the INR notices at checkout. Only the display currency changes.

class RegionOption {
  final String country;
  final String code;
  final String symbol;

  const RegionOption(this.country, this.code, this.symbol);
}

class CurrencyService {
  CurrencyService._();

  static const _prefsKey = 'mg_region';

  /// Regions offered in the header selector. Gulf/Arab markets (UAE, Saudi
  /// Arabia, Qatar, Kuwait, Oman, Bahrain) and Canada are not served.
  static const List<RegionOption> regions = [
    RegionOption('United States', 'USD', r'$'),
    RegionOption('United Kingdom', 'GBP', '£'),
    RegionOption('European Union', 'EUR', '€'),
    RegionOption('India', 'INR', '₹'),
    RegionOption('Australia', 'AUD', r'A$'),
  ];

  /// Notifies whenever the display region changes (pages listen + rebuild).
  static final ValueNotifier<String> region = ValueNotifier<String>('');

  static String? _country;
  static String? _override;
  static Map<String, double> _rates = const {
    'USD': 1,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.5,
    'AUD': 1.52,
  };

  /// Call once per session with the signed-in user's country (may be empty).
  static void configure(String? country) => _country = country;

  /// Loads the persisted header-selector choice (call once at startup).
  static Future<void> loadRegion() async {
    final prefs = await SharedPreferences.getInstance();
    _override = prefs.getString(_prefsKey) ?? '';
    region.value = _override ?? '';
  }

  /// Header selector: switches the display region and persists it.
  static Future<void> setRegion(String country) async {
    _override = country;
    region.value = country;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, country);
  }

  /// Replaces the FX table with the admin-managed rates from the API.
  static void setRates(Map<String, dynamic> rates) {
    final parsed = <String, double>{};
    rates.forEach((key, value) {
      final v = (value as num?)?.toDouble();
      if (key.length == 3 || key == 'BTC' || key == 'ETH') {
        if (v != null && v > 0) parsed[key.toUpperCase()] = v;
      }
    });
    if (parsed.isNotEmpty) _rates = parsed;
  }

  static String get _regionCountry {
    if (_override != null && _override!.isNotEmpty) return _override!;
    return _country ?? '';
  }

  /// Region name resolved to a selector entry (for the dropdown value).
  static String get regionCountryName {
    final c = _regionCountry.toLowerCase().trim();
    for (final r in regions) {
      if (r.country.toLowerCase() == c) return r.country;
    }
    return _regionCountry.isEmpty ? 'United States' : _regionCountry;
  }

  static bool get _isUs {
    final c = _regionCountry.toLowerCase();
    return c.contains('united states') ||
        c.trim() == 'usa' ||
        c.trim() == 'us' ||
        c.contains('america');
  }

  static bool get _isUk {
    final c = _regionCountry.toLowerCase().trim();
    return c == 'uk' ||
        c.contains('united kingdom') ||
        c.contains('england') ||
        c.contains('scotland') ||
        c.contains('wales');
  }

  static bool get _isEurope {
    final c = _regionCountry.toLowerCase().trim();
    return c == 'eu' ||
        c.contains('european union') ||
        c.contains('europe') ||
        c.contains('germany') ||
        c.contains('france') ||
        c.contains('netherlands');
  }

  /// The display currency for the selected region.
  /// Payments always settle in INR — see [settlementInr].
  static String get currencyCode {
    if (_isUs) return 'USD';
    if (_isUk) return 'GBP';
    if (_isEurope) return 'EUR';
    final c = _regionCountry.toLowerCase();
    if (c.contains('india')) return 'INR';
    if (c.contains('australia')) return 'AUD';
    return 'USD';
  }

  static String get currencySymbol {
    for (final r in regions) {
      if (r.code == currencyCode) return r.symbol;
    }
    return r'$';
  }

  static double get _fxToDisplay => _rates[currencyCode] ?? 1;

  static double get inrPerUsd => _rates['INR'] ?? 83.5;

  /// Converts a USD catalogue price into the display currency.
  static double convert(double usd) => usd * _fxToDisplay;

  /// Formats a USD catalogue price in the display currency: `$12.50` / `€11.50`.
  static String format(double usd) {
    final converted = convert(usd);
    final whole = converted.floor();
    final frac = ((converted - whole) * 100).round();
    final wholeStr = whole.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$currencySymbol$wholeStr.${frac.toString().padLeft(2, '0')}';
  }

  /// Formats a price as the regional amount with the USD catalogue price in
  /// parentheses, e.g. `£9.90 / unit ($12.50)`.
  static String priceLine(double usd) {
    if (usd <= 0) return 'Price on request';
    final base = r'$' + usd.toStringAsFixed(2);
    return '${format(usd)} / unit  ($base)';
  }

  /// Formats the INR settlement amount for an invoice (remittance channels).
  static String settlementInr(double usd) {
    final inr = usd * inrPerUsd;
    final whole = inr.floor().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '₹$whole';
  }

  /// Locale-aware formatting helper used by the chat quotation.
  static String localeName(Locale? locale) =>
      locale?.languageCode ?? 'en';
}