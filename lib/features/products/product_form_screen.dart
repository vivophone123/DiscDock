import 'dart:async';
import 'package:flutter/material.dart';
import 'product.dart';
import 'product_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = เพิ่มใหม่, มีค่า = แก้ไข
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _desc;
  late String _platform;
  late String _condition;
  late String _region;
  late bool _hasBox;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _title = TextEditingController(text: p?.title ?? '');
    _price = TextEditingController(text: p == null ? '' : '${p.price}');
    _stock = TextEditingController(text: p == null ? '' : '${p.stock}');
    _desc = TextEditingController(text: p?.description ?? '');
    _platform = p?.platform ?? 'PS5';
    _condition = p?.condition ?? 'new';
    _region = p?.region ?? 'Asia';
    _hasBox = p?.hasBox ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _stock.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final p = Product(
      id: widget.product?.id ?? '',
      title: _title.text.trim(),
      platform: _platform,
      condition: _condition,
      region: _region,
      hasBox: _hasBox,
      price: double.parse(_price.text),
      stock: int.parse(_stock.text),
      description: _desc.text.trim(),
      imageUrls: widget.product?.imageUrls ?? const [],
    );
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      // ถ้าออฟไลน์ Firestore จะรอซิงก์ จึงตั้ง timeout ไว้
      await (_isEdit ? _service.update(p) : _service.add(p))
          .timeout(const Duration(seconds: 8));
      messenger.showSnackBar(const SnackBar(content: Text('บันทึกแล้ว')));
      nav.pop();
    } on TimeoutException {
      messenger.showSnackBar(const SnackBar(
          content: Text('ออฟไลน์: บันทึกในเครื่องแล้ว จะซิงก์เมื่อมีอินเทอร์เน็ต')));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'แก้ไขสินค้า' : 'เพิ่มสินค้า')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'ชื่อเกม', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'กรอกชื่อเกม' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _platform,
              decoration: const InputDecoration(
                  labelText: 'แพลตฟอร์ม', border: OutlineInputBorder()),
              items: const ['PS5', 'PS4', 'Switch']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _platform = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _condition,
              decoration: const InputDecoration(
                  labelText: 'สภาพ', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('มือหนึ่ง')),
                DropdownMenuItem(value: 'used', child: Text('มือสอง')),
              ],
              onChanged: (v) => setState(() => _condition = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _region,
              decoration: const InputDecoration(
                  labelText: 'โซน', border: OutlineInputBorder()),
              items: const ['Asia', 'Region 1', 'Region 2', 'Region 3']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _region = v!),
            ),
            SwitchListTile(
              title: const Text('มีกล่อง'),
              value: _hasBox,
              onChanged: (v) => setState(() => _hasBox = v),
            ),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'ราคา (บาท)', border: OutlineInputBorder()),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0) ? 'กรอกราคาให้ถูกต้อง' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'สต๊อก (ชิ้น)', border: OutlineInputBorder()),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return (n == null || n < 0) ? 'กรอกจำนวนให้ถูกต้อง' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'รายละเอียด', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('บันทึก'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}