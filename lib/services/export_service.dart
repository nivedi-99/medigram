import 'dart:convert' show utf8;

import 'api_client.dart';
import 'file_saver.dart';

/// Downloads the admin CSV exports served by the MediGram API
/// (GET /api/v1/exports/*) and hands them to the browser (web) or disk.
class ExportService {
  ExportService._();

  /// Full catalogue (incl. hidden) - admins.
  static Future<String> productsCsv() =>
      _download('/exports/products.csv', 'medigram-products.csv');

  /// Every registered user - super admin only.
  static Future<String> usersCsv() =>
      _download('/exports/users.csv', 'medigram-users.csv');

  /// All orders with payment method / status / totals - admins.
  static Future<String> ordersCsv() =>
      _download('/exports/orders.csv', 'medigram-orders-payments.csv');

  /// Printable invoice for one order (by order uuid) - admins.
  static Future<String> invoiceCsv(String orderId) =>
      _download('/exports/invoice/$orderId.csv', 'invoice-$orderId.csv');

  static Future<String> _download(String path, String filename) async {
    final csv = await ApiClient.getText(path);
    return saveDownload(filename, utf8.encode(csv));
  }
}
