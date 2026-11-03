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
  final double subtotal;
  final double discount;
  final String couponCode;
  final double total;
  final String status;
  final DateTime? createdAt;
  final String shipName;
  final String shipPhone;
  final String shipAddress;
  final String carrier;
  final String trackingNumber;
  final String slipUrl;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.couponCode,
    required this.total,
    required this.status,
    this.createdAt,
    this.shipName = '',
    this.shipPhone = '',
    this.shipAddress = '',
    this.carrier = '',
    this.trackingNumber = '',
    this.slipUrl = '',
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
    final ship = (d['shipping'] as Map?) ?? {};
    final total = (d['total'] ?? 0).toDouble();
    return OrderModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      items: lines,
      subtotal: (d['subtotal'] ?? total).toDouble(),
      discount: (d['discount'] ?? 0).toDouble(),
      couponCode: (d['couponCode'] ?? '').toString(),
      total: total,
      status: d['status'] ?? 'pending_payment',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      shipName: (ship['name'] ?? '').toString(),
      shipPhone: (ship['phone'] ?? '').toString(),
      shipAddress: (ship['address'] ?? '').toString(),
      carrier: (d['carrier'] ?? '').toString(),
      trackingNumber: (d['trackingNumber'] ?? '').toString(),
      slipUrl: (d['slipUrl'] ?? '').toString(),
    );
  }

  String get shortId => id.substring(0, 6).toUpperCase();

  bool get hasShipping => shipAddress.isNotEmpty;
  bool get hasTracking => trackingNumber.isNotEmpty;
  bool get hasSlip => slipUrl.isNotEmpty;

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