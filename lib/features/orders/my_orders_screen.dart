import 'package:flutter/material.dart';
import 'order_model.dart';
import 'order_repo.dart';
import 'payment_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ออเดอร์ของฉัน')),
      body: StreamBuilder<List<OrderModel>>(
        stream: OrderRepo().watchMine(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('โหลดออเดอร์ไม่สำเร็จ'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('ยังไม่มีคำสั่งซื้อ'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('ออเดอร์ #${o.shortId}'),
                  subtitle: Text(
                      '${o.statusText}\n${o.items.length} รายการ • ฿${o.total.toStringAsFixed(0)}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PaymentScreen(orderId: o.id))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}