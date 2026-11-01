import 'package:cloud_firestore/cloud_firestore.dart';

class CouponException implements Exception {
  final String message;
  CouponException(this.message);
  @override
  String toString() => message;
}

class Coupon {
  final String code;
  final String type; // percent | fixed
  final double value;
  final double minSpend;
  final int maxUses; // 0 = ไม่จำกัด
  final int usedCount;
  final bool active;

  Coupon({
    required this.code,
    required this.type,
    required this.value,
    this.minSpend = 0,
    this.maxUses = 0,
    this.usedCount = 0,
    this.active = true,
  });

  factory Coupon.fromMap(String id, Map<String, dynamic> d) => Coupon(
        code: id,
        type: d['type'] ?? 'percent',
        value: (d['value'] ?? 0).toDouble(),
        minSpend: (d['minSpend'] ?? 0).toDouble(),
        maxUses: (d['maxUses'] ?? 0).toInt(),
        usedCount: (d['usedCount'] ?? 0).toInt(),
        active: d['active'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'type': type,
        'value': value,
        'minSpend': minSpend,
        'maxUses': maxUses,
        'usedCount': usedCount,
        'active': active,
      };

  String get label => type == 'percent'
      ? 'ลด ${value.toStringAsFixed(0)}%'
      : 'ลด ฿${value.toStringAsFixed(0)}';

  /// คืนเหตุผลถ้าใช้ไม่ได้ หรือ null ถ้าใช้ได้
  String? invalidReason(double subtotal) {
    if (!active) return 'คูปองนี้ปิดใช้งานแล้ว';
    if (maxUses > 0 && usedCount >= maxUses) return 'คูปองนี้ถูกใช้ครบแล้ว';
    if (subtotal < minSpend) {
      return 'ต้องซื้อขั้นต่ำ ฿${minSpend.toStringAsFixed(0)}';
    }
    return null;
  }

  /// ส่วนลดเป็นบาท (ไม่ให้ยอดสุทธิต่ำกว่า 1 บาท เพราะ QR ต้องมียอด)
  double discountFor(double subtotal) {
    final d = type == 'percent' ? subtotal * value / 100 : value;
    final cap = subtotal > 1 ? subtotal - 1 : 0.0;
    return d > cap ? cap : d;
  }
}

class CouponService {
  final _col = FirebaseFirestore.instance.collection('coupons');

  static String normalize(String c) => c.trim().toUpperCase();

  Future<Coupon> validate(String raw, double subtotal) async {
    final code = normalize(raw);
    if (code.isEmpty) throw CouponException('กรุณากรอกรหัสคูปอง');
    final doc = await _col.doc(code).get();
    if (!doc.exists) throw CouponException('ไม่พบรหัสคูปองนี้');
    final c = Coupon.fromMap(doc.id, doc.data()!);
    final reason = c.invalidReason(subtotal);
    if (reason != null) throw CouponException(reason);
    return c;
  }

  Stream<List<Coupon>> watchAll() => _col.snapshots().map((s) {
        final list =
            s.docs.map((d) => Coupon.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.code.compareTo(b.code));
        return list;
      });

  Future<void> add(Coupon c) async {
    final ref = _col.doc(c.code);
    if ((await ref.get()).exists) {
      throw CouponException('มีรหัสคูปองนี้แล้ว');
    }
    await ref.set({...c.toMap(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> setActive(String code, bool v) =>
      _col.doc(code).update({'active': v});

  Future<void> delete(String code) => _col.doc(code).delete();
}