import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/shop_config.dart';
import '../../core/utils/promptpay.dart';
import '../../services/cloudinary_service.dart';
import 'order_model.dart';
import 'order_repo.dart';
import 'slip_viewer.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  const PaymentScreen({super.key, required this.orderId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _cloud = CloudinaryService();
  bool _uploading = false;

  Future<void> _attachSlip() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      if (file == null) return;
      setState(() => _uploading = true);
      final url = await _cloud.uploadImage(file);
      await OrderRepo().attachSlip(widget.orderId, url);
      messenger.showSnackBar(
          const SnackBar(content: Text('ส่งสลิปแล้ว รอร้านตรวจสอบ')));
    } on UploadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on FirebaseException catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('ส่งสลิปไม่สำเร็จ (${e.code})')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('ส่งสลิปไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 17 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  Widget _slipCard(OrderModel o, {required bool pending}) {
    return Card(
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            o.slipUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            semanticLabel: 'รูปสลิปการโอนเงิน',
            errorBuilder: (_, __, ___) =>
                const SizedBox(width: 48, height: 48, child: Icon(Icons.broken_image)),
          ),
        ),
        title: Text(pending ? 'ส่งสลิปแล้ว รอร้านตรวจสอบ' : 'สลิปการโอนเงิน'),
        subtitle: const Text('แตะเพื่อดูสลิป'),
        onTap: () => showSlip(context, o.slipUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดออเดอร์')),
      body: StreamBuilder<OrderModel?>(
        stream: OrderRepo().watchOne(widget.orderId),
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
                    'สแกนด้วยแอปธนาคาร โอนเสร็จแล้วแนบสลิปด้านล่าง\nหน้านี้จะอัปเดตสถานะอัตโนมัติเมื่อร้านยืนยัน',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                if (o.hasSlip) _slipCard(o, pending: true),
                if (_uploading) const LinearProgressIndicator(),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(o.hasSlip ? 'เปลี่ยนสลิป' : 'แนบสลิปการโอน'),
                    onPressed: _uploading ? null : _attachSlip,
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                          o.status == 'shipped'
                              ? Icons.local_shipping
                              : Icons.check_circle,
                          color: Colors.green,
                          size: 72),
                      const SizedBox(height: 8),
                      Text(o.statusText,
                          style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                if (o.hasSlip) ...[
                  const SizedBox(height: 12),
                  _slipCard(o, pending: false),
                ],
              ],
              if (o.hasTracking) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text('เลขพัสดุ ${o.trackingNumber}'),
                    subtitle: Text('ขนส่ง: ${o.carrier}'),
                    trailing: IconButton(
                      tooltip: 'คัดลอกเลขพัสดุ',
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: o.trackingNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('คัดลอกเลขพัสดุแล้ว')));
                      },
                    ),
                  ),
                ),
              ],
              const Divider(height: 32),
              for (final l in o.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.title),
                  subtitle: Text(l.platform),
                  trailing:
                      Text('฿${l.price.toStringAsFixed(0)} x ${l.qty}'),
                ),
              const SizedBox(height: 8),
              if (o.discount > 0) ...[
                _line('ยอดสินค้า', '฿${o.subtotal.toStringAsFixed(0)}'),
                _line(
                    o.couponCode.isEmpty
                        ? 'ส่วนลด'
                        : 'ส่วนลด (${o.couponCode})',
                    '-฿${o.discount.toStringAsFixed(0)}'),
              ],
              _line('ยอดสุทธิ', '฿${o.total.toStringAsFixed(0)}', bold: true),
              const Divider(height: 32),
              const Text('ที่อยู่จัดส่ง',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (o.hasShipping) ...[
                Text('${o.shipName} • ${o.shipPhone}'),
                Text(o.shipAddress),
              ] else
                const Text('ไม่มีข้อมูลที่อยู่ (ออเดอร์เก่า)'),
            ],
          );
        },
      ),
    );
  }
}