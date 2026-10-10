import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/shop_config.dart';
import '../../core/utils/promptpay.dart';
import 'order_model.dart';
import 'order_repo.dart';

class PaymentScreen extends StatelessWidget {
  final String orderId;
  const PaymentScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ชำระเงิน')),
      body: StreamBuilder<OrderModel?>(
        stream: OrderRepo().watchOne(orderId),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('โหลดออเดอร์ไม่สำเร็จ'));
          }
          final o = snap.data;
          if (o == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final pending = o.status == 'pending_payment';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('ออเดอร์ #${o.shortId}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('สถานะ: ${o.statusText}'),
              const SizedBox(height: 16),
              if (pending) ...[
                Center(
                  child: QrImageView(
                    data: promptPayPayload(promptPayId, o.total),
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('ยอดชำระ ฿${o.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'สแกนด้วยแอปธนาคาร แล้วรอร้านยืนยัน\nหน้านี้จะอัปเดตสถานะอัตโนมัติ',
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 72),
                      const SizedBox(height: 8),
                      Text(o.statusText,
                          style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              const Divider(height: 32),
              for (final l in o.items)
                ListTile(
                  dense: true,
                  title: Text(l.title),
                  subtitle: Text(l.platform),
                  trailing:
                      Text('฿${l.price.toStringAsFixed(0)} x ${l.qty}'),
                ),
            ],
          );
        },
      ),
    );
  }
}