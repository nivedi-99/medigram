import 'api_client.dart';

/// A global settlement channel (wire, Western Union, Remitly, crypto, ...).
class PaymentChannel {
  final String key;
  final String label;
  final String tagline;
  final Map<String, String> details;
  final String instructions;
  final int sortOrder;
  final bool active;

  const PaymentChannel({
    required this.key,
    required this.label,
    this.tagline = '',
    this.details = const {},
    this.instructions = '',
    this.sortOrder = 0,
    this.active = true,
  });

  factory PaymentChannel.fromMap(Map<String, dynamic> map) {
    final rawDetails = map['details'];
    return PaymentChannel(
      key: map['key']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      tagline: map['tagline']?.toString() ?? '',
      instructions: map['instructions']?.toString() ?? '',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      active: map['active'] as bool? ?? true,
      details: rawDetails is Map<String, dynamic>
          ? rawDetails.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
    );
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'tagline': tagline,
        'details': details,
        'instructions': instructions,
        'sortOrder': sortOrder,
        'active': active,
      };
}

/// The full settlement configuration served by GET/PUT /api/v1/payments.
class PaymentsConfig {
  final String whatsappNumber;
  final Map<String, double> fx;
  final List<PaymentChannel> methods;

  const PaymentsConfig({
    required this.whatsappNumber,
    required this.fx,
    required this.methods,
  });

  factory PaymentsConfig.fromMap(Map<String, dynamic> map) {
    final rawFx = map['fx'];
    return PaymentsConfig(
      whatsappNumber: map['whatsappNumber']?.toString() ?? '',
      fx: rawFx is Map<String, dynamic>
          ? rawFx.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
          : const {},
      methods: (map['methods'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentChannel.fromMap)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'whatsappNumber': whatsappNumber,
        'fx': fx,
        'methods': methods.map((m) => m.toMap()).toList(),
      };
}

/// Reads and writes the global settlement configuration.
class PaymentsService {
  PaymentsService._();

  /// GET /api/v1/payments — `{ data: { whatsappNumber, fx, methods } }`.
  static Future<PaymentsConfig> fetchConfig() async {
    final body = await ApiClient.get('/payments');
    final data = body['data'] as Map<String, dynamic>? ?? {};
    return PaymentsConfig.fromMap(data);
  }

  /// PUT /api/v1/payments — replace the whole config (admin only).
  static Future<void> saveConfig(PaymentsConfig config) async {
    await ApiClient.put('/payments', body: config.toMap());
  }
}