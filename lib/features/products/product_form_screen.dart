import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import 'product.dart';
import 'product_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = เพิ่มใหม่, มีค่า = แก้ไข
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _maxImages = 5;

  final _formKey = GlobalKey<FormState>();
  final _service = ProductService();
  final _cloud = CloudinaryService();
  late final TextEditingController _title;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _desc;
  late String _platform;
  late String _condition;
  late String _region;
  late bool _hasBox;
  late List<String> _urls; // รูปที่อัปโหลดแล้ว
  final List<XFile> _picked = []; // รูปที่เพิ่งเลือก ยังไม่อัปโหลด
  bool _saving = false;
  String _status = '';

  bool get _isEdit => widget.product != null;
  int get _imageCount => _urls.length + _picked.length;

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
    _urls = List<String>.from(p?.imageUrls ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _stock.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final room = _maxImages - _imageCount;
    if (room <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เพิ่มรูปได้สูงสุด 5 รูป')));
      return;
    }
    try {
      final files = await ImagePicker()
          .pickMultiImage(imageQuality: 75, maxWidth: 1280);
      if (files.isEmpty) return;
      setState(() => _picked.addAll(files.take(room)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เลือกรูปไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _status = '';
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    // 1) อัปโหลดรูปใหม่ไป Cloudinary
    final allUrls = List<String>.from(_urls);
    try {
      for (var i = 0; i < _picked.length; i++) {
        if (mounted) {
          setState(() => _status = 'กำลังอัปโหลดรูป ${i + 1}/${_picked.length}');
        }
        allUrls.add(await _cloud.uploadImage(_picked[i]));
      }
    } on UploadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _saving = false);
      return;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
      if (mounted) setState(() => _saving = false);
      return;
    }

    // 2) บันทึกลง Firestore
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
      imageUrls: allUrls,
    );
    try {
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

  Widget _thumb({required Widget image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 88,
          height: 88,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey)),
          clipBehavior: Clip.antiAlias,
          child: image,
        ),
        Positioned(
          right: 10,
          top: 2,
          child: GestureDetector(
            onTap: _saving ? null : onRemove,
            child: const CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black87,
                child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
      ],
    );
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
            Text('รูปสินค้า ($_imageCount/$_maxImages)'),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _urls.length; i++)
                    _thumb(
                      image: Image.network(_urls[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image)),
                      onRemove: () => setState(() => _urls.removeAt(i)),
                    ),
                  for (var i = 0; i < _picked.length; i++)
                    _thumb(
                      image: Image.file(File(_picked[i].path),
                          fit: BoxFit.cover),
                      onRemove: () => setState(() => _picked.removeAt(i)),
                    ),
                  InkWell(
                    onTap: _saving ? null : _pickImages,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey)),
                      child: const Icon(Icons.add_photo_alternate_outlined,
                          size: 32),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                          if (_status.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Text(_status),
                          ],
                        ],
                      )
                    : const Text('บันทึก'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}