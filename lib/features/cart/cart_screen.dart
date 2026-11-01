import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../coupons/coupon_service.dart';
import '../orders/order_service.dart';
import '../orders/payment_screen.dart';
import 'cart_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;
  final _couponInput = TextEditingController();
  Coupon? _coupon;
  bool _loading = false;
  bool _checking = false;

  @override
  void dispose() {
    _couponInput.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// คูปองที่ใช้ได้กับยอดปัจจุบัน (ถ้ายอดลดจนไม่ถึงขั้นต่ำ จะไม่ใช้)
  Coupon? _validCoupon(double subtotal) {
    final c = _coupon;
    if (c == null) return null;
    return c.invalidReason(subtotal) == null ? c : null;
  }

  Future<void> _applyCoupon() async {
    setState(() => _checking = true);
    try {
      final c =
          await CouponService().validate(_couponInput.text, _cart.total);
      if (!mounted) return;
      setState(() => _coupon = c);
      _snack('ใช้คูปอง ${c.code} แล้ว');
    } on CouponException catch (e) {
      _snack(e.message);
    } on FirebaseException {
      _snack('ตรวจสอบคูปองไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต');
    } catch (_) {
      _snack('เกิดข้อผิดพลาด กรุณาลองใหม่');
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _checkout() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final id = await OrderService().placeOrder(_cart.items,
          couponCode: _validCoupon(_cart.total)?.code);
      _cart.clear();
      if (!mounted) return;
      nav.pushReplacement(
          MaterialPageRoute(builder: (_) => PaymentScreen(orderId: id)));
      return;
    } on OrderException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on FirebaseException catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.code == 'unavailable'
              ? 'เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาลองใหม่'
              : 'สั่งซื้อไม่สำเร็จ (${e.code})')));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontSize: bold ? 20 : 15,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  Widget _couponBox(double subtotal, Coupon? valid) {
    final c = _coupon;
    if (c == null) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _couponInput,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'รหัสคูปอง',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _checking ? null : _applyCoupon,
            child: const Text('ใช้คูปอง'),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(valid != null
              ? 'คูปอง ${c.code} (${c.label})'
              : 'คูปอง ${c.code} ใช้ไม่ได้: ${c.invalidReason(subtotal)}'),
        ),
        IconButton(
          tooltip: 'ยกเลิกคูปอง',
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _coupon = null;
            _couponInput.clear();
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตะกร้าสินค้า')),
      body: ListenableBuilder(
        listenable: _cart,
        builder: (context, _) {
          final items = _cart.items;
          if (items.isEmpty) {
            return const Center(child: Text('ตะกร้าว่างเปล่า'));
          }
          final subtotal = _cart.total;
          final valid = _validCoupon(subtotal);
          final discount = valid?.discountFor(subtotal) ?? 0;
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final p = it.product;
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text(
                          '${p.platform} • ฿${p.price.toStringAsFixed(0)} x ${it.qty}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'ลดจำนวน ${p.title}',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _cart.decrease(p.id),
                          ),
                          Text('${it.qty}'),
                          IconButton(
                            tooltip: 'เพิ่มจำนวน ${p.title}',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              if (!_cart.add(p)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'สต๊อกมี ${p.stock} ชิ้นเท่านั้น')));
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'ลบ ${p.title} ออกจากตะกร้า',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _cart.remove(p.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _couponBox(subtotal, valid),
                      const SizedBox(height: 8),
                      _row('ยอดสินค้า', '฿${subtotal.toStringAsFixed(0)}'),
                      if (discount > 0)
                        _row('ส่วนลด', '-฿${discount.toStringAsFixed(0)}'),
                      _row('ยอดสุทธิ',
                          '฿${(subtotal - discount).toStringAsFixed(0)}',
                          bold: true),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _checkout,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Text('สั่งซื้อและชำระเงิน'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}