import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/email_config.dart';
import '../../services/email_service.dart';
import '../notifications/notification_service.dart';
import 'order_model.dart';

class OrderRepo {
  final _col = FirebaseFirestore.instance.collection('orders');

  List<OrderModel> _toList(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(OrderModel.fromDoc).toList();
    final now = DateTime.now();
    // เรียงใหม่สุดก่อน (ออเดอร์ที่เพิ่งสร้างอาจยังไม่มีเวลา ให้ถือว่าใหม่สุด)
    list.sort(
        (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    return list;
  }

  Stream<List<OrderModel>> watchMine() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _col.where('userId', isEqualTo: uid).snapshots().map(_toList);
  }

  Stream<List<OrderModel>> watchAll() => _col.snapshots().map(_toList);

  Stream<OrderModel?> watchOne(String id) => _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? OrderModel.fromDoc(d) : null);

  /// ลูกค้าแนบสลิปการโอน (ใช้ได้เมื่อออเดอร์ยังรอชำระ)
  Future<void> attachSlip(String id, String url) async {
    await _col.doc(id).update({
      'slipUrl': url,
      'slipAt': FieldValue.serverTimestamp(),
    });
    final short = id.substring(0, 6).toUpperCase();
    await NotificationService().notifyOwner('ลูกค้าแนบสลิปการโอน',
        'ออเดอร์ #$short แนบสลิปแล้ว กรุณาตรวจสอบและยืนยันรับเงิน');
    unawaited(EmailService.send(
      to: ownerEmail,
      subject: 'DiscDock: ลูกค้าแนบสลิป #$short',
      message: 'ออเดอร์ #$short มีการแนบสลิปการโอนเงิน\n'
          'กรุณาตรวจสอบในแอป แล้วกดยืนยันรับเงิน',
    ));
  }

  Future<void> setStatus(String id, String status) async {
    final ref = _col.doc(id);
    await ref.update({'status': status});

    final data = (await ref.get()).data();
    final uid = data?['userId'] as String?;
    if (uid == null) return;
    final short = id.substring(0, 6).toUpperCase();
    if (status == 'paid') {
      await NotificationService().notifyUser(uid, 'ร้านยืนยันการชำระเงินแล้ว',
          'ออเดอร์ #$short ชำระเงินเรียบร้อย กำลังเตรียมจัดส่ง');
      unawaited(EmailService.send(
        to: (data?['customerEmail'] ?? '').toString(),
        subject: 'DiscDock: ยืนยันการชำระเงิน #$short',
        message: 'ร้านได้รับการชำระเงินของออเดอร์ #$short เรียบร้อยแล้ว\n'
            'กำลังเตรียมจัดส่งสินค้า ขอบคุณที่ใช้บริการ DiscDock',
      ));
    }
  }

  /// ทำเครื่องหมายว่าส่งแล้ว พร้อมขนส่งและเลขพัสดุ
  Future<void> markShipped(
    String id, {
    required String carrier,
    required String trackingNumber,
  }) async {
    final ref = _col.doc(id);
    await ref.update({
      'status': 'shipped',
      'carrier': carrier,
      'trackingNumber': trackingNumber,
      'shippedAt': FieldValue.serverTimestamp(),
    });

    final data = (await ref.get()).data();
    final uid = data?['userId'] as String?;
    if (uid == null) return;
    final short = id.substring(0, 6).toUpperCase();
    await NotificationService().notifyUser(
        uid,
        'ร้านจัดส่งสินค้าแล้ว',
        'ออเดอร์ #$short ส่งทาง $carrier เลขพัสดุ $trackingNumber');
    unawaited(EmailService.send(
      to: (data?['customerEmail'] ?? '').toString(),
      subject: 'DiscDock: จัดส่งสินค้าแล้ว #$short',
      message: 'ออเดอร์ #$short ถูกจัดส่งแล้ว\n\n'
          'ขนส่ง: $carrier\nเลขพัสดุ: $trackingNumber\n\n'
          'ขอบคุณที่ใช้บริการ DiscDock',
    ));
  }
}