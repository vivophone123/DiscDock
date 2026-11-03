import 'package:flutter/material.dart';
import '../cart/cart_service.dart';
import 'product.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

enum _Sort { newest, priceAsc, priceDesc, name }

const _sortLabels = {
  _Sort.newest: 'ใหม่ล่าสุด',
  _Sort.priceAsc: 'ราคา: ต่ำไปสูง',
  _Sort.priceDesc: 'ราคา: สูงไปต่ำ',
  _Sort.name: 'ชื่อเกม A-Z',
};

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
  RangeValues? _range; // null = ไม่กรองราคา
  bool _inStockOnly = false;
  _Sort _sort = _Sort.newest;

  /// ราคาสูงสุดในรายการ ปัดขึ้นเป็นหลักร้อย (ใช้เป็นขอบของแถบเลื่อน)
  double _maxPrice() {
    var m = 0.0;
    for (final p in widget.items) {
      if (p.price > m) m = p.price;
    }
    if (m <= 0) return 1000;
    return (m / 100).ceil() * 100.0;
  }

  bool get _filterActive => _range != null || _inStockOnly;
  bool get _anyActive =>
      _filterActive || _platform != null || _condition != null;

  Future<void> _openFilter(double maxPrice) async {
    var range = _range ?? RangeValues(0, maxPrice);
    range = RangeValues(
        range.start.clamp(0.0, maxPrice), range.end.clamp(0.0, maxPrice));
    var inStock = _inStockOnly;
    final divisions = (maxPrice / 100).round().clamp(1, 100);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ตัวกรอง', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                  'ช่วงราคา ฿${range.start.round()} - ฿${range.end.round()}'),
              RangeSlider(
                values: range,
                min: 0,
                max: maxPrice,
                divisions: divisions,
                labels: RangeLabels(
                    '฿${range.start.round()}', '฿${range.end.round()}'),
                onChanged: (v) => setSheet(() => range = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เฉพาะสินค้าที่มีของ'),
                value: inStock,
                onChanged: (v) => setSheet(() => inStock = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, 'clear'),
                      child: const Text('ล้างตัวกรอง'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'apply'),
                      child: const Text('ตกลง'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (result == 'clear') {
        _range = null;
        _inStockOnly = false;
      } else {
        _range = (range.start <= 0 && range.end >= maxPrice) ? null : range;
        _inStockOnly = inStock;
      }
    });
  }

  Widget? _trailing(BuildContext context, Product p) {
    if (widget.isOwner) {
      return PopupMenuButton<String>(
        tooltip: 'จัดการสินค้า ${p.title}',
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
      tooltip: 'ใส่ ${p.title} ลงตะกร้า',
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

  Widget _leading(Product p) {
    const size = 56.0;
    if (p.imageUrls.isEmpty) {
      return const SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.album, size: 32, semanticLabel: 'ไม่มีรูปสินค้า'));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        p.imageUrls.first,
        semanticLabel: 'รูปปก ${p.title}',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.broken_image, semanticLabel: 'โหลดรูปไม่สำเร็จ')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxPrice = _maxPrice();
    final shown = widget.items.where((p) {
      final okName = p.title.toLowerCase().contains(_query.toLowerCase());
      final okPlatform = _platform == null || p.platform == _platform;
      final okCond = _condition == null || p.condition == _condition;
      final r = _range;
      final okPrice = r == null ||
          (p.price >= r.start && (r.end >= maxPrice || p.price <= r.end));
      final okStock = !_inStockOnly || p.stock > 0;
      return okName && okPlatform && okCond && okPrice && okStock;
    }).toList();

    switch (_sort) {
      case _Sort.newest:
        break; // ลำดับเดิมจากฐานข้อมูลคือใหม่ล่าสุดก่อน
      case _Sort.priceAsc:
        shown.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _Sort.priceDesc:
        shown.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _Sort.name:
        shown.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
          child: Row(
            children: [
              Expanded(
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
              IconButton(
                tooltip: 'ตัวกรอง',
                icon: Badge(
                  smallSize: 9,
                  isLabelVisible: _filterActive,
                  child: const Icon(Icons.tune),
                ),
                onPressed: () => _openFilter(maxPrice),
              ),
              PopupMenuButton<_Sort>(
                tooltip: 'เรียงลำดับ',
                icon: const Icon(Icons.sort),
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final e in _sortLabels.entries)
                    PopupMenuItem(value: e.key, child: Text(e.value)),
                ],
              ),
            ],
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                    'พบ ${shown.length} รายการ • ${_sortLabels[_sort]}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (_anyActive)
                TextButton(
                  onPressed: () => setState(() {
                    _platform = null;
                    _condition = null;
                    _range = null;
                    _inStockOnly = false;
                  }),
                  child: const Text('ล้างตัวกรองทั้งหมด'),
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
                        leading: _leading(p),
                        title: Text(p.title),
                        subtitle: Text(
                            '${p.platform} • ${p.condition == 'new' ? 'มือหนึ่ง' : 'มือสอง'} • ${p.region}\n'
                            '฿${p.price.toStringAsFixed(0)} • เหลือ ${p.stock} ชิ้น'),
                        isThreeLine: true,
                        trailing: _trailing(context, p),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                    product: p, isOwner: widget.isOwner))),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}