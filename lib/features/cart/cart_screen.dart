import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Map<String, String>? _shipping; // name, phone, address
  String _profileName = '';
  String _profilePhone = '';
  bool _loading = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _couponInput.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// ดึงที่อยู่เริ่มต้นที่เคยบันทึกไว้ (ถ้ามี)
  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final d = (await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get())
          .data();
      _profileName = (d?['name'] ?? '').toString();
      _profilePhone = (d?['phone'] ?? '').toString();
      final addr = (d?['address'] ?? '').toString();
      if (addr.isNotEmpty && mounted && _shipping == null) {
        setState(() => _shipping = {
              'name': _profileName,
              'phone': _profilePhone,
              'address': addr,
            });
      }
    } catch (_) {}
  }

  void _saveDefault(Map<String, String> s) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'phone': s['phone'],
      'address': s['address'],
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  Future<void> _editShipping() async {
    final r = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ShippingSheet(
        initial: _shipping ??
            {'name': _profileName, 'phone': _profilePhone, 'address': ''},
      ),
    );
    if (r == null || !mounted) return;
    final s = {
      'name': r['name']!,
      'phone': r['phone']!,
      'address': r['address']!,
    };
    setState(() => _shipping = s);
    if (r['save'] == '1') _saveDefault(s);
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
    if (_shipping == null) {
      _snack('กรุณาเพิ่มที่อยู่จัดส่งก่อนสั่งซื้อ');
      await _editShipping();
      return;
    }
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final id = await OrderService().placeOrder(
        _cart.items,
        couponCode: _validCoupon(_cart.total)?.code,
        shipping: _shipping!,
      );
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

  Widget _shippingCard() {
    final s = _shipping;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(s == null
            ? 'ยังไม่มีที่อยู่จัดส่ง'
            : '${s['name']} • ${s['phone']}'),
        subtitle: Text(s == null ? 'แตะเพื่อเพิ่มที่อยู่' : s['address']!),
        trailing: s == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'แก้ไขที่อยู่จัดส่ง',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _editShipping,
              ),
        onTap: _editShipping,
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
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == items.length) return _shippingCard();
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

/// แบบฟอร์มที่อยู่จัดส่ง (bottom sheet)
class _ShippingSheet extends StatefulWidget {
  final Map<String, String>? initial;
  const _ShippingSheet({this.initial});

  @override
  State<_ShippingSheet> createState() => _ShippingSheetState();
}

class _ShippingSheetState extends State<_ShippingSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _save = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?['name'] ?? '');
    _phone = TextEditingController(text: widget.initial?['phone'] ?? '');
    _address = TextEditingController(text: widget.initial?['address'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'save': _save ? '1' : '0',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ที่อยู่จัดส่ง',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'ชื่อผู้รับ', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'กรอกชื่อผู้รับ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'เบอร์โทร', border: OutlineInputBorder()),
                validator: (v) => RegExp(r'^[0-9]{9,10}$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : 'เบอร์โทรต้องเป็นตัวเลข 9-10 หลัก',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'ที่อยู่ (บ้านเลขที่ ถนน แขวง/ตำบล เขต/อำเภอ จังหวัด รหัสไปรษณีย์)',
                    border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'กรอกที่อยู่ให้ครบถ้วน'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('บันทึกเป็นที่อยู่เริ่มต้น'),
                value: _save,
                onChanged: (v) => setState(() => _save = v ?? false),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('ใช้ที่อยู่นี้'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}