import 'package:flutter/material.dart';
import 'coupon_service.dart';

class CouponsScreen extends StatelessWidget {
  const CouponsScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ทำรายการไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Coupon c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบคูปอง'),
        content: Text('ต้องการลบคูปอง ${c.code} ใช่หรือไม่'),
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
    if (ok == true && context.mounted) {
      await _run(context, () => CouponService().delete(c.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = CouponService();
    return Scaffold(
      appBar: AppBar(title: const Text('คูปองส่วนลด')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('สร้างคูปอง'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CouponFormScreen())),
      ),
      body: StreamBuilder<List<Coupon>>(
        stream: service.watchAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('โหลดคูปองไม่สำเร็จ'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('ยังไม่มีคูปอง'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('${c.code} • ${c.label}'),
                  subtitle: Text(
                      'ขั้นต่ำ ฿${c.minSpend.toStringAsFixed(0)} • ใช้แล้ว ${c.usedCount}/${c.maxUses == 0 ? 'ไม่จำกัด' : c.maxUses}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: c.active,
                        onChanged: (v) => _run(
                            context, () => service.setActive(c.code, v)),
                      ),
                      IconButton(
                        tooltip: 'ลบคูปอง',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, c),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CouponFormScreen extends StatefulWidget {
  const CouponFormScreen({super.key});

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _minSpend = TextEditingController();
  final _maxUses = TextEditingController();
  String _type = 'percent';
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minSpend.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await CouponService()
          .add(Coupon(
            code: CouponService.normalize(_code.text),
            type: _type,
            value: double.parse(_value.text),
            minSpend: double.tryParse(_minSpend.text) ?? 0,
            maxUses: int.tryParse(_maxUses.text) ?? 0,
          ))
          .timeout(const Duration(seconds: 10));
      messenger.showSnackBar(const SnackBar(content: Text('สร้างคูปองแล้ว')));
      nav.pop();
      return;
    } on CouponException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('สร้างคูปองไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างคูปอง')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'รหัสคูปอง (A-Z, 0-9 ความยาว 3-20)',
                  border: OutlineInputBorder()),
              validator: (v) => RegExp(r'^[A-Za-z0-9]{3,20}$')
                      .hasMatch((v ?? '').trim())
                  ? null
                  : 'ใช้ตัวอักษร/ตัวเลข 3-20 ตัว',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: 'ประเภทส่วนลด', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'percent', child: Text('ลดเป็นเปอร์เซ็นต์')),
                DropdownMenuItem(value: 'fixed', child: Text('ลดเป็นบาท')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: _type == 'percent' ? 'ลดกี่ %' : 'ลดกี่บาท',
                  border: const OutlineInputBorder()),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'กรอกค่าให้ถูกต้อง';
                if (_type == 'percent' && n > 100) return 'ไม่เกิน 100%';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minSpend,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'ยอดซื้อขั้นต่ำ (บาท) เว้นว่าง = ไม่มี',
                  border: OutlineInputBorder()),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final n = double.tryParse(v!);
                return (n == null || n < 0) ? 'กรอกตัวเลขให้ถูกต้อง' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxUses,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'จำกัดจำนวนครั้ง เว้นว่าง = ไม่จำกัด',
                  border: OutlineInputBorder()),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final n = int.tryParse(v!);
                return (n == null || n < 0) ? 'กรอกตัวเลขให้ถูกต้อง' : null;
              },
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