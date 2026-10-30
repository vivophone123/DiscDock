import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<void> setStatus(String id, String status) async {
    final ref = _col.doc(id);
    await ref.update({'status': status});

    final uid = (await ref.get()).data()?['userId'] as String?;
    if (uid == null) return;
    final short = id.substring(0, 6).toUpperCase();
    if (status == 'paid') {
      await NotificationService().notifyUser(uid, 'ร้านยืนยันการชำระเงินแล้ว',
          'ออเดอร์ #$short ชำระเงินเรียบร้อย กำลังเตรียมจัดส่ง');
    } else if (status == 'shipped') {
      await NotificationService().notifyUser(
          uid, 'ร้านจัดส่งสินค้าแล้ว', 'ออเดอร์ #$short ถูกจัดส่งแล้ว');
    }
  }
}