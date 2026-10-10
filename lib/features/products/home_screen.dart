import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/profile_screen.dart';
import '../cart/cart_screen.dart';
import '../cart/cart_service.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_screen.dart';
import '../orders/my_orders_screen.dart';
import '../orders/owner_orders_screen.dart';
import 'product.dart';
import 'product_form_screen.dart';
import 'product_list.dart';
import 'product_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบสินค้า'),
        content: Text('ต้องการลบ "${p.title}" ใช่หรือไม่'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ProductService().delete(p.id).timeout(const Duration(seconds: 8));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // บัญชีเพิ่งถูกลบ/ออกจากระบบ รอให้แอปสลับไปหน้าล็อกอิน
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final isOwner = userSnap.data?.data()?['role'] == 'owner';
        return Scaffold(
          appBar: AppBar(
            title: const Text('DiscDock'),
            actions: [
              if (!isOwner)
                ListenableBuilder(
                  listenable: CartService.instance,
                  builder: (context, _) => IconButton(
                    icon: Badge(
                      label: Text('${CartService.instance.count}'),
                      isLabelVisible: CartService.instance.count > 0,
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CartScreen())),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: isOwner ? 'แชทลูกค้า' : 'แชทกับร้าน',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => isOwner
                            ? const ChatListScreen()
                            : ChatScreen(
                                roomId: uid,
                                title: 'แชทกับร้าน',
                                isOwner: false))),
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long_outlined),
                tooltip: isOwner ? 'ออเดอร์ร้าน' : 'ออเดอร์ของฉัน',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => isOwner
                            ? const OwnerOrdersScreen()
                            : const MyOrdersScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'ข้อมูลสมาชิก',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'ออกจากระบบ',
                onPressed: () => AuthService().logout(),
              ),
            ],
          ),
          floatingActionButton: isOwner
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มสินค้า'),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProductFormScreen())),
                )
              : null,
          body: StreamBuilder<List<Product>>(
            stream: ProductService().watchAll(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return const Center(child: Text('ยังไม่มีสินค้า'));
              }
              return ProductList(
                items: items,
                isOwner: isOwner,
                onDelete: (p) => _confirmDelete(context, p),
              );
            },
          ),
        );
      },
    );
  }
}