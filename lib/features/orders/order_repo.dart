import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_model.dart';

class OrderRepo {
  final _col = FirebaseFirestore.instance.collection('orders');

  List<OrderModel> _toList(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map(OrderModel.fromDoc).toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    // เรียงใหม่สุดก่อน (ออเดอร์ที่เพิ่งสร้างอาจยังไม่มีเวลา ให้ถือว่าใหม่สุด)
    list.sort((a, b) => (b.createdAt ?? DateTime.now().add(const Duration(days: 1)))
        .compareTo(a.createdAt ?? DateTime.now().add(const Duration(days: 1))));
    return list.where((o) => o.createdAt != epoch).toList();
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

  Future<void> setStatus(String id, String status) =>
      _col.doc(id).update({'status': status});
}