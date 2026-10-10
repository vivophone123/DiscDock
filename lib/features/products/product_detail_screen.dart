import 'package:flutter/material.dart';
import '../cart/cart_service.dart';
import 'product.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final bool isOwner;
  const ProductDetailScreen(
      {super.key, required this.product, required this.isOwner});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(
        children: [
          SizedBox(
            height: 280,
            child: p.imageUrls.isEmpty
                ? const Center(child: Icon(Icons.image_not_supported, size: 64))
                : PageView.builder(
                    itemCount: p.imageUrls.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => Image.network(
                      p.imageUrls[i],
                      fit: BoxFit.contain,
                      loadingBuilder: (c, child, prog) => prog == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
          ),
          if (p.imageUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < p.imageUrls.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('฿${p.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('${p.platform} • ${p.condition == 'new' ? 'มือหนึ่ง' : 'มือสอง'}'
                    ' • โซน ${p.region} • ${p.hasBox ? 'มีกล่อง' : 'ไม่มีกล่อง'}'),
                const SizedBox(height: 4),
                Text(p.stock == 0 ? 'สินค้าหมด' : 'เหลือ ${p.stock} ชิ้น'),
                if (p.description.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(p.description),
                ],
                if (!widget.isOwner) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_shopping_cart),
                      label: Text(p.stock == 0 ? 'สินค้าหมด' : 'ใส่ตะกร้า'),
                      onPressed: p.stock == 0
                          ? null
                          : () {
                              final ok = CartService.instance.add(p);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(ok
                                          ? 'เพิ่ม "${p.title}" ในตะกร้าแล้ว'
                                          : 'สต๊อกมี ${p.stock} ชิ้นเท่านั้น')));
                            },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}