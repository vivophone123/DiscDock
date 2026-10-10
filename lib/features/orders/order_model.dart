import 'package:cloud_firestore/cloud_firestore.dart';

class OrderLine {
  final String title;
  final String platform;
  final double price;
  final int qty;
  OrderLine(this.title, this.platform, this.price, this.qty);
}

class OrderModel {
  final String id;
  final String userId;
  final List<OrderLine> items;
  final double total;
  final String status;
  final DateTime? createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    required this.status,
    this.createdAt,
  });

  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final lines = (d['items'] as List? ?? [])
        .map((e) => OrderLine(
              e['title'] ?? '',
              e['platform'] ?? '',
              (e['price'] ?? 0).toDouble(),
              (e['qty'] ?? 0).toInt(),
            ))
        .toList();
    return OrderModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      items: lines,
      total: (d['total'] ?? 0).toDouble(),
      status: d['status'] ?? 'pending_payment',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get shortId => id.substring(0, 6).toUpperCase();

  String get statusText {
    switch (status) {
      case 'pending_payment':
        return 'รอชำระเงิน';
      case 'paid':
        return 'ชำระแล้ว (เตรียมส่ง)';
      case 'shipped':
        return 'ส่งแล้ว';
      default:
        return status;
    }
  }
}