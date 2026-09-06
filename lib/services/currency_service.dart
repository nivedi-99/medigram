import 'dart:ui';

/// Regional display pricing for the MediGram catalogue.
///
/// * United States / USA  -> USD (`$`)
/// * Europe (EU + UK)     -> EUR (`€`)
/// * Everywhere else      -> USD base
///
/// Prices are authored in USD; conversion uses the admin-managed FX table
/// (see /api/v1/payments). Settlement is always quoted in INR separately.
class CurrencyService {
  CurrencyService._();

  static const Set<String> _euCountries = {
    'austria', 'belgium', 'bulgaria', 'croatia', 'cyprus', 'czech republic',
    'czechia', 'denmark', 'estonia', 'finland', 'france', 'germany', 'greece',
    'hungary', 'ireland', 'italy', 'latvia', 'lithuania', 'luxembourg',
    'malta', 'netherlands', 'poland', 'portugal', 'romania', 'slovakia',
    'slovenia', 'spain', 'sweden',
    // Colloquially "Europe" for display purposes:
    'united kingdom', 'uk', 'england', 'scotland', 'wales',
  };

  static String? _country;
  static Map<String, double> _rates = const {
    'USD': 1,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.5,
    'BTC': 0.0000152,
    'ETH': 0.00019,
    'USDT': 1,
  };

  /// Call once per session with the signed-in user's country (may be empty).
  static void configure(String? country) => _country = country;

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

  static bool get _isUs {
    final c = (_country ?? '').toLowerCase();
    return c.contains('united states') ||
        c.trim() == 'usa' ||
        c.trim() == 'us' ||
        c.contains('america');
  }

  static bool get _isEurope {
    final c = (_country ?? '').toLowerCase().trim();
    if (_euCountries.contains(c)) return true;
    return _euCountries.any((e) => c.isNotEmpty && c.contains(e));
  }

  /// The display currency for this session: USD or EUR (INR is settlement).
  static String get currencyCode => _isUs ? 'USD' : _isEurope ? 'EUR' : 'USD';

  static String get currencySymbol => _isEurope ? '€' : '\$';

  static double get _fxToDisplay =>
      _rates[currencyCode] ?? (_isEurope ? 0.92 : 1);

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

  /// Formats a USD price with its regional conversion annotation.
  static String priceLine(double usd) {
    if (usd <= 0) return 'Price on request';
    final base = '\$${usd.toStringAsFixed(2)}';
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