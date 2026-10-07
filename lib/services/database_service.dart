import '../models/models.dart';
import 'api_client.dart';
import 'cart_service.dart';
import 'product_image.dart';

/// Admin-side data access. Every call goes through the MediGram API
/// (Render) — Row Level Security on the database stays as defense-in-depth.
class DatabaseService {
  DatabaseService._();

  // ---------------------------------------------------------------------
  // Client database (client_profiles)
  // ---------------------------------------------------------------------

  /// Lists B2B clients, optionally filtered by verification status.
  static Future<List<ClientRecord>> fetchClients({
    String? verificationStatus,
  }) async {
    final body = await ApiClient.get('/clients', query: {
      if (verificationStatus != null) 'status': verificationStatus,
    });
    final rows = body['data'] as List<dynamic>;
    return rows
        .map((r) => ClientRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// P2 · verifies or rejects a client's KYC status.
  static Future<void> setClientVerification({
    required String clientId,
    required String status, // 'verified' | 'rejected' | 'pending'
  }) async {
    await ApiClient.patch('/clients/$clientId/verify',
        body: {'status': status});
  }

  /// Assigns a client to an admin handler.
  static Future<void> assignClientToAdmin({
    required String clientId,
    required String adminUserId,
  }) async {
    await ApiClient.patch('/clients/$clientId/assign',
        body: {'adminUserId': adminUserId});
  }

  // ---------------------------------------------------------------------
  // Admin database (admin_handlers)
  // ---------------------------------------------------------------------

  /// Lists admin handlers plus role counts (super admin view).
  static Future<List<AdminRecord>> fetchAdmins() async {
    final body = await ApiClient.get('/admins');
    final rows = body['data']['handlers'] as List<dynamic>;
    return rows
        .map((r) => AdminRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Role totals for the super-admin overview.
  static Future<Map<UserRole, int>> fetchRoleCounts() async {
    final body = await ApiClient.get('/admins');
    final raw = body['data']['roleCounts'] as Map<String, dynamic>;
    final counts = <UserRole, int>{
      UserRole.client: (raw['client'] as num?)?.toInt() ?? 0,
      UserRole.admin: (raw['admin'] as num?)?.toInt() ?? 0,
      UserRole.superAdmin: (raw['super_admin'] as num?)?.toInt() ?? 0,
    };
    return counts;
  }

  /// P5 · promotes a user (looked up by email) to admin.
  static Future<void> promoteToAdmin({required String email}) async {
    await ApiClient.post('/admins/promote', body: {'email': email});
  }

  /// P5 · demotes an admin back to client.
  static Future<void> demoteAdmin({required String userId}) async {
    await ApiClient.post('/admins/demote', body: {'userId': userId});
  }

  /// Activates / deactivates an admin handler row (server-side toggle).
  static Future<void> setAdminActive({
    required String adminRowId,
    required bool active,
  }) async {
    // The API toggles the current value; the dashboard refreshes afterwards.
    await ApiClient.patch('/admins/$adminRowId/toggle');
  }

  // ---------------------------------------------------------------------
  // Catalogue & orders
  // ---------------------------------------------------------------------

  static Future<List<ProductRecord>> fetchProducts({
    bool activeOnly = true,
  }) async {
    final body = await ApiClient.get('/products');
    final rows = body['data'] as List<dynamic>;
    return rows
        .map((r) => ProductRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Lightweight order statistics for the admin dashboard.
  static Future<Map<String, int>> fetchOrderStats() async {
    final body = await ApiClient.get('/orders/stats');
    final raw = body['data'] as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  /// Admin order feed - GET /orders returns every order for admins.
  static Future<List<MedicineOrder>> fetchAllOrders() async {
    final body = await ApiClient.get('/orders', query: {'limit': '100'});
    final rows = body['data'] as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(MedicineOrder.fromApi)
        .toList();
  }

  /// Admin marks an order paid / pending (PATCH /orders/:id/payment).
  static Future<void> setOrderPaymentStatus({
    required String orderId,
    required bool paid,
  }) async {
    await ApiClient.patch('/orders/$orderId/payment',
        body: {'paymentStatus': paid ? 'paid' : 'pending'});
  }

  // ---------------------------------------------------------------------
  // Client portal (the signed-in user's own data)
  // ---------------------------------------------------------------------

  /// The signed-in client's export orders (newest first).
  static Future<List<MedicineOrder>> fetchMyOrders() async {
    final body = await ApiClient.get('/orders');
    final rows = body['data'] as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(MedicineOrder.fromApi)
        .toList();
  }

  /// The signed-in user's notification inbox (newest first).
  static Future<List<AppNotification>> fetchMyNotifications() async {
    final body = await ApiClient.get('/notifications');
    final rows = body['data'] as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromApi)
        .toList();
  }

  /// Marks a single notification as read (ownership enforced server-side).
  static Future<void> markNotificationRead(String id) async {
    await ApiClient.patch('/notifications/$id/read');
  }

  /// Marks every unread notification as read.
  static Future<void> markAllNotificationsRead() async {
    await ApiClient.patch('/notifications/read-all');
  }

  // ---------------------------------------------------------------------
  // Ordering & reports
  // ---------------------------------------------------------------------

  /// P3 · places an export order from the cart. The server resolves prices
  /// and enforces MOQ / verified-client rules; the response is the full
  /// order with its items.
  static Future<MedicineOrder> placeOrder({
    required List<CartItem> items,
    String incoterms = 'FOB',
    String paymentMethod = 'Wire Transfer',
    String shippingAddress = '',
    String notes = '',
  }) async {
    final body = await ApiClient.post('/orders', body: {
      'items': items
          .map((i) => {'productId': i.productId, 'quantity': i.quantity})
          .toList(),
      'incoterms': incoterms,
      'paymentMethod': paymentMethod,
      'shippingAddress': shippingAddress,
      'notes': notes,
    });
    return MedicineOrder.fromApi(body['data'] as Map<String, dynamic>);
  }

  /// Submits a product issue report for one of the client's orders.
  static Future<void> submitProductReport({
    required String orderId,
    required String productName,
    required String issueType,
    String details = '',
  }) async {
    await ApiClient.post('/reports', body: {
      'orderId': orderId,
      'productName': productName,
      'issueType': issueType,
      'details': details,
    });
  }

  // -------------------------------------------------------------------
  // Admin catalogue management — P7 writes (admin role enforced server-side)
  // -------------------------------------------------------------------

  /// Creates a catalogue entry (POST /products).
  static Future<ProductRecord> createProduct({
    required String name,
    required String category,
    String manufacturer = '',
    String description = '',
    String strength = '',
    String imageUrl = '',
    required double price,
    int minOrderQty = 1,
  }) async {
    final body = await ApiClient.post('/products', body: {
      'name': name,
      'category': category,
      'manufacturer': manufacturer,
      'description': description,
      'strength': strength,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'price': price,
      'currency': 'USD',
      'minOrderQty': minOrderQty,
    });
    return ProductRecord.fromMap(body['data'] as Map<String, dynamic>);
  }

  /// Uploads a product photo the admin picked in the browser and returns its
  /// permanent public URL (POST /uploads/product-image). The photo is pinned
  /// to the product's canonical storage path, so it resolves even before the
  /// products.image_url column exists.
  static Future<String> uploadProductImage(
    PickedImage image, {
    required String productId,
  }) async {
    final body = await ApiClient.upload(
      '/uploads/product-image',
      filename: image.filename,
      bytes: image.bytes,
      contentType: image.contentType,
      headers: {'x-product-id': productId},
    );
    final data = body['data'] as Map<String, dynamic>;
    return data['url']?.toString() ?? '';
  }

  /// Best-effort storage cleanup after an admin removes/replaces a photo.
  /// Never throws — an orphaned object must not break the UI flow.
  static Future<void> deleteProductImage(String url) async {
    if (url.isEmpty) return;
    try {
      await ApiClient.delete(
          '/uploads/product-image?url=${Uri.encodeComponent(url)}');
    } catch (_) {
      // Ignore: the catalogue row is already cleared via PATCH /products/:id.
    }
  }

  /// Soft-deletes a catalogue entry (DELETE /products/:id) - the row
  /// stays for order history but is_active=false hides it from buyers.
  static Future<void> deleteProduct({required String id}) async {
    await ApiClient.delete('/products/$id');
  }

  /// Edits a catalogue entry (PATCH /products/:id).
  static Future<ProductRecord> updateProduct({
    required String id,
    String? category,
    String? manufacturer,
    String? description,
    String? strength,
    String? imageUrl,
    double? price,
    int? minOrderQty,
    bool? isActive,
  }) async {
    final body = await ApiClient.patch('/products/$id', body: {
      if (category != null) 'category': category,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (description != null) 'description': description,
      if (strength != null) 'strength': strength,
      // '' clears the photo, so pass it through whenever it was touched.
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (price != null) 'price': price,
      if (minOrderQty != null) 'minOrderQty': minOrderQty,
      if (isActive != null) 'isActive': isActive,
    });
    return ProductRecord.fromMap(body['data'] as Map<String, dynamic>);
  }
}
