import 'package:flutter/material.dart';
import '../cart/cart_service.dart';
import 'product.dart';
import 'product_form_screen.dart';

class ProductList extends StatefulWidget {
  final List<Product> items;
  final bool isOwner;
  final void Function(Product) onDelete;

  const ProductList({
    super.key,
    required this.items,
    required this.isOwner,
    required this.onDelete,
  });

  @override
  State<ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  String _query = '';
  String? _platform;
  String? _condition;

  Widget? _trailing(BuildContext context, Product p) {
    if (widget.isOwner) {
      return PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductFormScreen(product: p)));
          } else {
            widget.onDelete(p);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
          PopupMenuItem(value: 'delete', child: Text('ลบ')),
        ],
      );
    }
    if (p.stock == 0) return const Text('หมด');
    return IconButton(
      icon: const Icon(Icons.add_shopping_cart),
      onPressed: () {
        final ok = CartService.instance.add(p);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok
                ? 'เพิ่ม "${p.title}" ในตะกร้าแล้ว'
                : 'สต๊อกมี ${p.stock} ชิ้นเท่านั้น')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.items.where((p) {
      final okName = p.title.toLowerCase().contains(_query.toLowerCase());
      final okPlatform = _platform == null || p.platform == _platform;
      final okCond = _condition == null || p.condition == _condition;
      return okName && okPlatform && okCond;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ค้นหาเกม...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final pf in const ['PS5', 'PS4', 'Switch'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(pf),
                    selected: _platform == pf,
                    onSelected: (s) =>
                        setState(() => _platform = s ? pf : null),
                  ),
                ),
              FilterChip(
                label: const Text('มือหนึ่ง'),
                selected: _condition == 'new',
                onSelected: (s) =>
                    setState(() => _condition = s ? 'new' : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('มือสอง'),
                selected: _condition == 'used',
                onSelected: (s) =>
                    setState(() => _condition = s ? 'used' : null),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('ไม่พบสินค้าที่ตรงกับเงื่อนไข'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final p = shown[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(p.title),
                        subtitle: Text(
                            '${p.platform} • ${p.condition == 'new' ? 'มือหนึ่ง' : 'มือสอง'} • ${p.region}\n'
                            '฿${p.price.toStringAsFixed(0)} • เหลือ ${p.stock} ชิ้น'),
                        isThreeLine: true,
                        trailing: _trailing(context, p),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}