import 'package:flutter/foundation.dart';
import '../products/product.dart';

class CartItem {
  final Product product;
  int qty;
  CartItem(this.product, this.qty);
}

class CartService extends ChangeNotifier {
  CartService._();
  static final instance = CartService._();

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();
  int get count => _items.values.fold<int>(0, (s, e) => s + e.qty);
  double get total =>
      _items.values.fold<double>(0, (s, e) => s + e.product.price * e.qty);

  /// คืน false ถ้าเกินสต๊อก
  bool add(Product p) {
    final cur = _items[p.id];
    final next = (cur?.qty ?? 0) + 1;
    if (next > p.stock) return false;
    if (cur == null) {
      _items[p.id] = CartItem(p, 1);
    } else {
      cur.qty = next;
    }
    notifyListeners();
    return true;
  }

  void decrease(String id) {
    final cur = _items[id];
    if (cur == null) return;
    if (cur.qty <= 1) {
      _items.remove(id);
    } else {
      cur.qty--;
    }
    notifyListeners();
  }

  void remove(String id) {
    _items.remove(id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}