import 'package:flutter/material.dart';
import '../coupons/coupons_screen.dart';
import '../orders/order_model.dart';
import '../orders/order_repo.dart';
import '../orders/owner_orders_screen.dart';
import '../products/product.dart';
import '../products/product_form_screen.dart';
import '../products/product_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _baht(double v) => '฿${v.toStringAsFixed(0)}';

  Widget _stat(IconData icon, String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(label),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard ร้าน')),
      body: StreamBuilder<List<OrderModel>>(
        stream: OrderRepo().watchAll(),
        builder: (context, oSnap) {
          return StreamBuilder<List<Product>>(
            stream: ProductService().watchAll(),
            builder: (context, pSnap) {
              if (oSnap.hasError || pSnap.hasError) {
                return const Center(child: Text('โหลดข้อมูลไม่สำเร็จ'));
              }
              if (!oSnap.hasData || !pSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _content(context, oSnap.data!, pSnap.data!);
            },
          );
        },
      ),
    );
  }

  Widget _content(
      BuildContext context, List<OrderModel> orders, List<Product> products) {
    final now = DateTime.now();
    final confirmed = orders
        .where((o) => o.status == 'paid' || o.status == 'shipped')
        .toList();
    final pending = orders.where((o) => o.status == 'pending_payment').length;

    final todaySales = confirmed
        .where((o) => o.createdAt != null && _sameDay(o.createdAt!, now))
        .fold<double>(0, (s, o) => s + o.total);
    final totalSales = confirmed.fold<double>(0, (s, o) => s + o.total);

    final days = List.generate(
        7,
        (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));
    final sums = days
        .map((d) => confirmed
            .where((o) => o.createdAt != null && _sameDay(o.createdAt!, d))
            .fold<double>(0, (s, o) => s + o.total))
        .toList();
    final maxSum = sums.fold<double>(0, (m, v) => v > m ? v : m);

    final qtyByTitle = <String, int>{};
    for (final o in confirmed) {
      for (final l in o.items) {
        qtyByTitle[l.title] = (qtyByTitle[l.title] ?? 0) + l.qty;
      }
    }
    final best = qtyByTitle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final low = products.where((p) => p.stock <= 2).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          _stat(Icons.today, 'ยอดขายวันนี้', _baht(todaySales)),
          _stat(Icons.hourglass_bottom, 'ออเดอร์รอชำระ', '$pending'),
        ]),
        Row(children: [
          _stat(Icons.payments_outlined, 'ยอดขายรวม', _baht(totalSales)),
          _stat(Icons.check_circle_outline, 'ออเดอร์ที่ชำระแล้ว',
              '${confirmed.length}'),
        ]),
        _title(context, 'ยอดขาย 7 วันล่าสุด'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (sums[i] > 0)
                            Text(sums[i].toStringAsFixed(0),
                                style: const TextStyle(fontSize: 11)),
                          Container(
                            height: maxSum == 0
                                ? 2
                                : 2 + 80 * sums[i] / maxSum,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${days[i].day}/${days[i].month}',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        _title(context, 'เกมขายดี'),
        Card(
          child: best.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ยังไม่มีข้อมูลการขาย'))
              : Column(
                  children: [
                    for (var i = 0; i < best.length && i < 5; i++)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                            radius: 14, child: Text('${i + 1}')),
                        title: Text(best[i].key),
                        trailing: Text('${best[i].value} ชิ้น'),
                      ),
                  ],
                ),
        ),
        _title(context, 'แผ่นใกล้หมด (เหลือไม่เกิน 2 ชิ้น)'),
        Card(
          child: low.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('ไม่มีสินค้าใกล้หมด'))
              : Column(
                  children: [
                    for (final p in low.take(5))
                      ListTile(
                        dense: true,
                        title: Text('${p.title} (${p.platform})'),
                        trailing: Text(
                          p.stock == 0 ? 'หมด' : 'เหลือ ${p.stock}',
                          style: TextStyle(
                              color: p.stock == 0
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
        ),
        _title(context, 'ทางลัด'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มสินค้า'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProductFormScreen())),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('ออเดอร์ร้าน'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const OwnerOrdersScreen())),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.discount_outlined),
              label: const Text('คูปอง'),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CouponsScreen())),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}