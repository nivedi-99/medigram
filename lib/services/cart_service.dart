import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// One line in the client's cart.
class CartItem {
  final String productId;
  final String name;
  final double unitPrice;
  final int minOrderQty;
  int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.minOrderQty,
    this.quantity = 1,
  });

  double get lineTotal => quantity * unitPrice;
}

/// Session cart for the client portal. Backed by a [ValueNotifier] so cart
/// badges update reactively across pages.
class CartService {
  CartService._();

  static final List<CartItem> _items = [];
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static List<CartItem> get items => List.unmodifiable(_items);
  static bool get isEmpty => _items.isEmpty;
  static double get total =>
      _items.fold(0, (sum, i) => sum + i.lineTotal);

  static void _notify() => count.value = _items.length;

  /// Adds a catalogue product. The first add starts at the minimum order qty.
  static void add(ProductRecord product) {
    final existing = _items
        .where((i) => i.productId == product.id)
        .toList(growable: false);
    if (existing.isNotEmpty) {
      existing.first.quantity += 1;
    } else {
      _items.add(CartItem(
        productId: product.id,
        name: product.name,
        unitPrice: product.price,
        minOrderQty: product.minOrderQty,
        quantity: product.minOrderQty,
      ));
    }
    _notify();
  }

  /// Adds every line of a past order (Reorder). Missing product ids are
  /// skipped — the API rejects orders referencing unknown products.
  static void addOrderItems(MedicineOrder order) {
    for (final item in order.items) {
      final pid = item.productId;
      if (pid == null || pid.isEmpty) continue;
      final existing =
          _items.where((i) => i.productId == pid).toList(growable: false);
      if (existing.isNotEmpty) {
        existing.first.quantity += item.quantity;
        continue;
      }
      _items.add(CartItem(
        productId: pid,
        name: item.name,
        unitPrice: item.price,
        minOrderQty: item.quantity,
        quantity: item.quantity,
      ));
    }
    _notify();
  }

  /// Sets the quantity of the item at [index], clamped to its MOQ.
  static void setQuantity(int index, int quantity) {
    if (index < 0 || index >= _items.length) return;
    final min = _items[index].minOrderQty;
    _items[index].quantity = quantity < min ? min : quantity;
    _notify();
  }

  static void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _notify();
  }

  static void clear() {
    _items.clear();
    _notify();
  }
}
