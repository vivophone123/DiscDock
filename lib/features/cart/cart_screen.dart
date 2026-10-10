import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../orders/order_service.dart';
import 'cart_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;
  bool _loading = false;

  Future<void> _checkout() async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await OrderService().placeOrder(_cart.items);
      _cart.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('สั่งซื้อสำเร็จ'),
          content: Text('รหัสออเดอร์: $id\nสถานะ: รอชำระเงิน'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ตกลง')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _cart.decrease(p.id),
                          ),
                          Text('${it.qty}'),
                          IconButton(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ยอดรวม',
                              style: TextStyle(fontSize: 16)),
                          Text('฿${_cart.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
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
                              : const Text('สั่งซื้อ'),
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