import 'package:flutter/material.dart';
import 'order_model.dart';
import 'order_repo.dart';

class OwnerOrdersScreen extends StatelessWidget {
  const OwnerOrdersScreen({super.key});

  Future<void> _set(BuildContext context, String id, String status) async {
    try {
      await OrderRepo().setStatus(id, status);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('อัปเดตไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ออเดอร์ร้าน')),
      body: StreamBuilder<List<OrderModel>>(
        stream: OrderRepo().watchAll(),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ออเดอร์ #${o.shortId} • ${o.statusText}',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      for (final l in o.items)
                        Text('${l.title} (${l.platform}) x${l.qty}'),
                      const SizedBox(height: 4),
                      Text('ยอดรวม ฿${o.total.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      if (o.status == 'pending_payment')
                        FilledButton(
                          onPressed: () => _set(context, o.id, 'paid'),
                          child: const Text('ยืนยันได้รับเงินแล้ว'),
                        ),
                      if (o.status == 'paid')
                        FilledButton(
                          onPressed: () => _set(context, o.id, 'shipped'),
                          child: const Text('ทำเครื่องหมายว่าส่งแล้ว'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}