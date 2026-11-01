
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:discdock/features/auth/auth_service.dart';
import 'package:discdock/features/cart/cart_service.dart';
import 'package:discdock/features/orders/order_model.dart';
import 'package:discdock/features/products/product.dart';

Product _game({
  String id = 'p1',
  String title = 'Elden Ring',
  double price = 1000,
  int stock = 3,
}) =>
    Product(
      id: id,
      title: title,
      platform: 'PS5',
      condition: 'new',
      region: 'Asia',
      hasBox: true,
      price: price,
      stock: stock,
    );

void main() {
  group('CartService', () {
    final cart = CartService.instance;

    setUp(() => cart.clear());

    test('TC01 เพิ่มสินค้าใหม่ลงตะกร้า ต้องคืน true และ count = 1', () {
      final ok = cart.add(_game());
      expect(ok, isTrue);
      expect(cart.count, 1);
      expect(cart.items.length, 1);
    });

    test('TC02 เพิ่มสินค้าเดิมซ้ำ จำนวนต้องเพิ่มขึ้น ไม่เกิดรายการใหม่', () {
      final p = _game();
      cart.add(p);
      cart.add(p);
      expect(cart.items.length, 1);
      expect(cart.items.first.qty, 2);
      expect(cart.count, 2);
    });

    test('TC03 เพิ่มเกินสต๊อก ต้องคืน false และจำนวนไม่เปลี่ยน', () {
      final p = _game(stock: 1);
      expect(cart.add(p), isTrue);
      expect(cart.add(p), isFalse);
      expect(cart.count, 1);
    });

    test('TC04 ยอดรวมคำนวณถูกต้องจากหลายสินค้า', () {
      final a = _game(id: 'a', price: 1000, stock: 5);
      final b = _game(id: 'b', price: 500, stock: 5);
      cart.add(a);
      cart.add(a);
      cart.add(b);
      expect(cart.total, 2500); // 1000*2 + 500*1
    });

    test('TC05 decrease เมื่อเหลือ 1 ชิ้น ต้องเอาออกจากตะกร้า', () {
      final p = _game();
      cart.add(p);
      cart.decrease(p.id);
      expect(cart.items, isEmpty);
      expect(cart.count, 0);
    });

    test('TC06 decrease เมื่อมีหลายชิ้น ต้องลดทีละ 1', () {
      final p = _game();
      cart.add(p);
      cart.add(p);
      cart.decrease(p.id);
      expect(cart.items.first.qty, 1);
    });

    test('TC07 remove ต้องลบรายการออกทั้งรายการ', () {
      final p = _game();
      cart.add(p);
      cart.add(p);
      cart.remove(p.id);
      expect(cart.items, isEmpty);
    });

    test('TC08 clear ต้องล้างตะกร้าและแจ้ง listener', () {
      cart.add(_game());
      var notified = 0;
      void listener() => notified++;
      cart.addListener(listener);
      cart.clear();
      cart.removeListener(listener);
      expect(cart.items, isEmpty);
      expect(notified, 1);
    });
  });

  group('Product', () {
    test('TC09 toMap ต้องมีฟิลด์ครบและค่าตรงกับ object', () {
      final m = _game(title: 'Zelda', price: 1590, stock: 2).toMap();
      expect(m['title'], 'Zelda');
      expect(m['platform'], 'PS5');
      expect(m['price'], 1590);
      expect(m['stock'], 2);
      expect(m['hasBox'], isTrue);
      expect(m['imageUrls'], isEmpty);
    });
  });

  group('OrderModel', () {
    OrderModel order(String status, {String id = 'abcdef123456'}) =>
        OrderModel(
          id: id,
          userId: 'u1',
          items: [OrderLine('Elden Ring', 'PS5', 1000, 1)],
          total: 1000,
          status: status,
        );

    test('TC10 shortId ต้องเป็น 6 ตัวแรก ตัวพิมพ์ใหญ่', () {
      expect(order('paid').shortId, 'ABCDEF');
    });

    test('TC11 statusText ของแต่ละสถานะเป็นข้อความภาษาไทยที่ถูกต้อง', () {
      expect(order('pending_payment').statusText, 'รอชำระเงิน');
      expect(order('paid').statusText, 'ชำระแล้ว (เตรียมส่ง)');
      expect(order('shipped').statusText, 'ส่งแล้ว');
    });

    test('TC12 สถานะที่ไม่รู้จัก ต้องแสดงค่าเดิมกลับมา', () {
      expect(order('xyz').statusText, 'xyz');
    });

    test('TC13 สถานะ cancelled แสดงว่ายกเลิกแล้ว', () {
      // ต้องเพิ่ม case 'cancelled' ใน order_model.dart ตามที่แก้ไว้ก่อนหน้า
      expect(order('cancelled').statusText, 'ยกเลิกแล้ว');
    });
  });

  group('AuthService.message', () {
    String msg(String code) =>
        AuthService.message(FirebaseAuthException(code: code));

    test('TC14 อีเมลรูปแบบผิด', () {
      expect(msg('invalid-email'), 'รูปแบบอีเมลไม่ถูกต้อง');
    });

    test('TC15 รหัสผ่านผิด/ไม่พบผู้ใช้ ใช้ข้อความเดียวกัน (ไม่เปิดเผยว่าผิดตรงไหน)',
        () {
      const expected = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      expect(msg('wrong-password'), expected);
      expect(msg('user-not-found'), expected);
      expect(msg('invalid-credential'), expected);
    });

    test('TC16 error code ที่ไม่รู้จัก ต้องแสดงรหัสให้ตรวจสอบได้', () {
      expect(msg('some-new-error'), contains('some-new-error'));
    });
  });
}