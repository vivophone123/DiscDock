import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/email_config.dart';
import '../../services/email_service.dart';
import '../cart/cart_service.dart';
import '../coupons/coupon_service.dart';
import '../notifications/notification_service.dart';

class OrderException implements Exception {
  final String message;
  OrderException(this.message);
  @override
  String toString() => message;
}

class OrderService {
  final _db = FirebaseFirestore.instance;

  /// สร้างออเดอร์ หักสต๊อก และใช้คูปองในขั้นตอนเดียว
  /// (ถ้าสต๊อกหรือคูปองไม่ผ่าน จะไม่สร้างอะไรเลย)
  /// shipping = {name, phone, address}
  Future<String> placeOrder(
    List<CartItem> items, {
    String? couponCode,
    required Map<String, String> shipping,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final customerEmail = user.email ?? '';
    final orderRef = _db.collection('orders').doc();
    double finalTotal = 0;

    await _db.runTransaction((tx) async {
      final refs = items
          .map((i) => _db.collection('products').doc(i.product.id))
          .toList();

      // ต้องอ่านทั้งหมดก่อน แล้วค่อยเขียน
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final r in refs) {
        snaps.add(await tx.get(r));
      }
      final couponRef = (couponCode != null && couponCode.isNotEmpty)
          ? _db
              .collection('coupons')
              .doc(CouponService.normalize(couponCode))
          : null;
      final couponSnap = couponRef == null ? null : await tx.get(couponRef);

      final lines = <Map<String, dynamic>>[];
      final stocks = <int>[];
      double subtotal = 0;

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
        subtotal += price * it.qty;
        lines.add({
          'productId': it.product.id,
          'title': d['title'] ?? '',
          'platform': d['platform'] ?? '',
          'condition': d['condition'] ?? '',
          'price': price,
          'qty': it.qty,
        });
      }

      double discount = 0;
      if (couponRef != null) {
        if (couponSnap == null || !couponSnap.exists) {
          throw OrderException('ไม่พบรหัสคูปองนี้');
        }
        final c = Coupon.fromMap(couponSnap.id, couponSnap.data()!);
        final reason = c.invalidReason(subtotal);
        if (reason != null) throw OrderException(reason);
        discount = c.discountFor(subtotal);
        tx.update(couponRef, {'usedCount': c.usedCount + 1});
      }
      final total = subtotal - discount;

      for (var i = 0; i < items.length; i++) {
        tx.update(refs[i], {'stock': stocks[i] - items[i].qty});
      }
      tx.set(orderRef, {
        'userId': user.uid,
        'customerEmail': customerEmail,
        'items': lines,
        'subtotal': subtotal,
        'discount': discount,
        'couponCode': couponRef?.id,
        'total': total,
        'shipping': {
          'name': shipping['name'] ?? '',
          'phone': shipping['phone'] ?? '',
          'address': shipping['address'] ?? '',
        },
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
      });
      finalTotal = total;
    });

    final short = orderRef.id.substring(0, 6).toUpperCase();
    await NotificationService().notifyOwner(
      'มีออเดอร์ใหม่',
      'ออเดอร์ #$short ยอด ฿${finalTotal.toStringAsFixed(0)} รอชำระเงิน',
    );

    // ส่งอีเมล (ไม่รอผล เพื่อไม่ให้หน้าจอค้าง และไม่กระทบการสั่งซื้อ)
    final itemLines = items
        .map((i) => '- ${i.product.title} (${i.product.platform}) x${i.qty}')
        .join('\n');
    final address =
        '${shipping['name']} โทร ${shipping['phone']}\n${shipping['address']}';
    unawaited(EmailService.send(
      to: customerEmail,
      subject: 'DiscDock: ได้รับคำสั่งซื้อ #$short',
      message: 'ขอบคุณที่สั่งซื้อกับ DiscDock\n\n'
          'ออเดอร์ #$short\n$itemLines\n\n'
          'ยอดสุทธิ ฿${finalTotal.toStringAsFixed(0)}\n\n'
          'ที่อยู่จัดส่ง\n$address\n\n'
          'สถานะ: รอชำระเงิน กรุณาสแกน PromptPay QR ในแอปเพื่อชำระเงิน',
    ));
    unawaited(EmailService.send(
      to: ownerEmail,
      subject: 'DiscDock: ออเดอร์ใหม่ #$short',
      message: 'มีออเดอร์ใหม่ #$short\n$itemLines\n\n'
          'ยอดสุทธิ ฿${finalTotal.toStringAsFixed(0)}\n'
          'ลูกค้า: $customerEmail\n\nที่อยู่จัดส่ง\n$address',
    ));

    return orderRef.id;
  }
}