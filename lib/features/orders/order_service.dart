import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../cart/cart_service.dart';

class OrderException implements Exception {
  final String message;
  OrderException(this.message);
  @override
  String toString() => message;
}

class OrderService {
  final _db = FirebaseFirestore.instance;

  /// สร้างออเดอร์ และหักสต๊อกในขั้นตอนเดียว (ถ้าสต๊อกไม่พอ จะไม่สร้างอะไรเลย)
  Future<String> placeOrder(List<CartItem> items) async {
    final user = FirebaseAuth.instance.currentUser!;
    final orderRef = _db.collection('orders').doc();

    await _db.runTransaction((tx) async {
      final refs = items
          .map((i) => _db.collection('products').doc(i.product.id))
          .toList();

      // ต้องอ่านทั้งหมดก่อน แล้วค่อยเขียน
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final r in refs) {
        snaps.add(await tx.get(r));
      }

      final lines = <Map<String, dynamic>>[];
      final stocks = <int>[];
      double total = 0;

      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        final s = snaps[i];
        if (!s.exists) {
          throw OrderException('"${it.product.title}" ถูกนำออกจากร้านแล้ว');
        }
        final d = s.data()!;
        final stock = (d['stock'] ?? 0).toInt();
        if (stock < it.qty) {
          throw OrderException(
              '"${it.product.title}" เหลือ $stock ชิ้น ไม่พอตามที่สั่ง');
        }
        final price = (d['price'] ?? 0).toDouble(); // ใช้ราคาจากเซิร์ฟเวอร์
        stocks.add(stock);
        total += price * it.qty;
        lines.add({
          'productId': it.product.id,
          'title': d['title'] ?? '',
          'platform': d['platform'] ?? '',
          'condition': d['condition'] ?? '',
          'price': price,
          'qty': it.qty,
        });
      }

      for (var i = 0; i < items.length; i++) {
        tx.update(refs[i], {'stock': stocks[i] - items[i].qty});
      }
      tx.set(orderRef, {
        'userId': user.uid,
        'items': lines,
        'total': total,
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return orderRef.id;
  }
}