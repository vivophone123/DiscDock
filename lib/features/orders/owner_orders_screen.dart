import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'order_model.dart';
import 'order_repo.dart';
import 'slip_viewer.dart';

const _carriers = [
  'ไปรษณีย์ไทย',
  'Kerry Express',
  'Flash Express',
  'J&T Express',
  'อื่นๆ',
];

class OwnerOrdersScreen extends StatelessWidget {
  const OwnerOrdersScreen({super.key});

  void _snack(BuildContext context, String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _markPaid(BuildContext context, OrderModel o) async {
    try {
      await OrderRepo().setStatus(o.id, 'paid');
    } catch (e) {
      _snack(context, 'อัปเดตไม่สำเร็จ: $e');
    }
  }

  Future<void> _ship(BuildContext context, OrderModel o) async {
    final r = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ShipDialog(),
    );
    if (r == null) return;
    try {
      await OrderRepo().markShipped(o.id,
          carrier: r['carrier']!, trackingNumber: r['tracking']!);
    } catch (e) {
      _snack(context, 'อัปเดตไม่สำเร็จ: $e');
    }
  }

  void _copyAddress(BuildContext context, OrderModel o) {
    Clipboard.setData(ClipboardData(
        text: '${o.shipName} ${o.shipPhone}\n${o.shipAddress}'));
    _snack(context, 'คัดลอกที่อยู่แล้ว');
  }

  Widget _slipRow(BuildContext context, OrderModel o) {
    if (!o.hasSlip) {
      return Text(
          o.status == 'pending_payment' ? 'ยังไม่มีสลิปการโอน' : 'ไม่มีสลิปแนบ',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return InkWell(
      onTap: () => showSlip(context, o.slipUrl),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              o.slipUrl,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              semanticLabel: 'รูปสลิปการโอนเงิน',
              errorBuilder: (_, __, ___) => const SizedBox(
                  width: 56, height: 56, child: Icon(Icons.broken_image)),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('ลูกค้าแนบสลิปแล้ว (แตะเพื่อดู)')),
        ],
      ),
    );
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
                      Text(
                          'ยอดรวม ฿${o.total.toStringAsFixed(0)}'
                          '${o.discount > 0 ? ' (ลด ฿${o.discount.toStringAsFixed(0)})' : ''}'),
                      const Divider(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: o.hasShipping
                                ? Text(
                                    '${o.shipName} • ${o.shipPhone}\n${o.shipAddress}')
                                : const Text('ไม่มีข้อมูลที่อยู่ (ออเดอร์เก่า)'),
                          ),
                          if (o.hasShipping)
                            IconButton(
                              tooltip: 'คัดลอกที่อยู่',
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () => _copyAddress(context, o),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _slipRow(context, o),
                      if (o.hasTracking) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                                    '${o.carrier}: ${o.trackingNumber}')),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (o.status == 'pending_payment')
                        FilledButton(
                          onPressed: () => _markPaid(context, o),
                          child: const Text('ยืนยันได้รับเงินแล้ว'),
                        ),
                      if (o.status == 'paid')
                        FilledButton.icon(
                          icon: const Icon(Icons.local_shipping_outlined),
                          onPressed: () => _ship(context, o),
                          label: const Text('จัดส่งแล้ว (ใส่เลขพัสดุ)'),
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

/// กล่องกรอกขนส่งและเลขพัสดุ
class _ShipDialog extends StatefulWidget {
  const _ShipDialog();

  @override
  State<_ShipDialog> createState() => _ShipDialogState();
}

class _ShipDialogState extends State<_ShipDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tracking = TextEditingController();
  String _carrier = _carriers.first;

  @override
  void dispose() {
    _tracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ข้อมูลการจัดส่ง'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _carrier,
              decoration: const InputDecoration(
                  labelText: 'ขนส่ง', border: OutlineInputBorder()),
              items: [
                for (final c in _carriers)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _carrier = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tracking,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'เลขพัสดุ', border: OutlineInputBorder()),
              validator: (v) =>
                  RegExp(r'^[A-Za-z0-9-]{6,30}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'เลขพัสดุเป็นตัวอักษร/ตัวเลข 6-30 ตัว',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'carrier': _carrier,
              'tracking': _tracking.text.trim().toUpperCase(),
            });
          },
          child: const Text('ยืนยัน'),
        ),
      ],
    );
  }
}