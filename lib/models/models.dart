class Customer {
  String name;
  String email;
  String phone;
  String address;
  DateTime joinedOn;

  Customer({
    required this.name,
    required this.email,
    required this.phone,
    this.address = '',
    DateTime? joinedOn,
  }) : joinedOn = joinedOn ?? DateTime.now();

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

enum OrderStatus { processing, shipped, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final String? productId;

  const OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.productId,
  });

  double get lineTotal => quantity * price;
}

class MedicineOrder {
  final String uuid;
  final String id;
  final DateTime date;
  final List<OrderItem> items;
  final OrderStatus status;
  final String paymentMethod;

  const MedicineOrder({
    required this.uuid,
    required this.id,
    required this.date,
    required this.items,
    required this.status,
    required this.paymentMethod,
  });

  double get total => items.fold(0, (sum, i) => sum + i.lineTotal);

  static OrderStatus statusFromApi(String? value) {
    switch (value) {
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.processing;
    }
  }

  factory MedicineOrder.fromApi(Map<String, dynamic> map) {
    final items = (map['order_items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((i) => OrderItem(
              name: (i['product_name'] ?? '') as String,
              quantity: (i['quantity'] as num?)?.toInt() ?? 0,
              price: (i['unit_price'] as num?)?.toDouble() ?? 0,
              productId: i['product_id']?.toString(),
            ))
        .toList();
    return MedicineOrder(
      uuid: (map['id'] ?? '') as String,
      id: (map['order_number'] ?? '') as String,
      date:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      items: items,
      status: statusFromApi(map['status']?.toString()),
      paymentMethod: (map['payment_method'] ?? '') as String,
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String subtitle;
  final DateTime time;
  final bool unread;
  final NotificationKind kind;

  const AppNotification({
    this.id = '',
    required this.title,
    required this.subtitle,
    required this.time,
    this.unread = false,
    this.kind = NotificationKind.general,
  });

  static NotificationKind kindFromApi(String? value) {
    switch (value) {
      case 'order':
        return NotificationKind.order;
      case 'kyc':
        return NotificationKind.support;
      case 'offer':
        return NotificationKind.offer;
      default:
        return NotificationKind.general;
    }
  }

  factory AppNotification.fromApi(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      subtitle: (map['body'] ?? '') as String,
      time: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      unread: !(map['is_read'] as bool? ?? false),
      kind: kindFromApi(map['kind']?.toString()),
    );
  }
}

enum NotificationKind { order, offer, general, support }

class SavedPaymentMethod {
  final String label;
  final String detail;
  final PaymentType type;
  bool isDefault;

  SavedPaymentMethod({
    required this.label,
    required this.detail,
    required this.type,
    this.isDefault = false,
  });
}

enum PaymentType { card, upi, wallet, cod }

// ---------------------------------------------------------------------------
// Supabase-backed user & role system (client / admin / super admin)
// ---------------------------------------------------------------------------

/// Application roles backed by the Postgres `user_role` enum.
enum UserRole {
  client,
  admin,
  superAdmin;

  /// Parses the raw string stored in the `profiles.role` column.
  static UserRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'super_admin':
        return UserRole.superAdmin;
      case 'client':
      default:
        return UserRole.client;
    }
  }

  String get label {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.admin:
        return 'Admin';
      case UserRole.superAdmin:
        return 'Super Admin';
    }
  }
}

/// The authenticated MediGram user, hydrated from the `profiles` table.
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String companyName;
  final String country;
  final bool isActive;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone = '',
    this.role = UserRole.client,
    this.companyName = '',
    this.country = '',
    this.isActive = true,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: UserRole.fromString(map['role']?.toString()),
      companyName: map['company_name']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  /// Maps this user onto the legacy [Customer] view-model used by the
  /// client-facing screens.
  Customer toCustomer() => Customer(
        name: fullName.isEmpty ? email.split('@').first : fullName,
        email: email,
        phone: phone,
        address: country,
        joinedOn: createdAt,
      );

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
}

/// Extended B2B record for a client, mirrors the `client_profiles` table.
class ClientRecord {
  final String id;
  final String userId;
  final String companyName;
  final String country;
  final String businessLicenseNo;
  final String importPermitNo;
  final String taxId;
  final String verificationStatus; // pending | verified | rejected
  final String assignedAdminId;
  final String contactEmail;
  final String contactPhone;
  final DateTime? createdAt;

  const ClientRecord({
    required this.id,
    required this.userId,
    this.companyName = '',
    this.country = '',
    this.businessLicenseNo = '',
    this.importPermitNo = '',
    this.taxId = '',
    this.verificationStatus = 'pending',
    this.assignedAdminId = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.createdAt,
  });

  factory ClientRecord.fromMap(Map<String, dynamic> map) {
    return ClientRecord(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      companyName: map['company_name']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      businessLicenseNo: map['business_license_no']?.toString() ?? '',
      importPermitNo: map['import_permit_no']?.toString() ?? '',
      taxId: map['tax_id']?.toString() ?? '',
      verificationStatus: map['verification_status']?.toString() ?? 'pending',
      assignedAdminId: map['assigned_admin_id']?.toString() ?? '',
      contactEmail: map['contact_email']?.toString() ?? '',
      contactPhone: map['contact_phone']?.toString() ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}

/// Admin staff member, mirrors the `admin_handlers` table.
class AdminRecord {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String department;
  final bool isActive;
  final DateTime? createdAt;

  const AdminRecord({
    required this.id,
    required this.userId,
    this.fullName = '',
    this.email = '',
    this.department = 'Client Servicing',
    this.isActive = true,
    this.createdAt,
  });

  factory AdminRecord.fromMap(Map<String, dynamic> map) {
    return AdminRecord(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      department: map['department']?.toString() ?? 'Client Servicing',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}

/// Product row exposed in the admin catalogue, mirrors the `products` table.
class ProductRecord {
  final String id;
  final String name;
  final String category;
  final String manufacturer;
  final String description;
  final double price;
  final int minOrderQty;
  final bool isActive;

  const ProductRecord({
    required this.id,
    required this.name,
    this.category = 'General',
    this.manufacturer = '',
    this.description = '',
    this.price = 0,
    this.minOrderQty = 1,
    this.isActive = true,
  });

  factory ProductRecord.fromMap(Map<String, dynamic> map) {
    return ProductRecord(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      manufacturer: map['manufacturer']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      minOrderQty: (map['min_order_qty'] as num?)?.toInt() ?? 1,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  /// Bundled category product shot for the catalogue cards.
  /// Category is slugged ('Drops & Syrups' -> drops-syrups) to match the
  /// generated images in web/assets/products/.
  String get imageAsset {
    final slug = category
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'assets/products/$slug.jpg';
  }
}

