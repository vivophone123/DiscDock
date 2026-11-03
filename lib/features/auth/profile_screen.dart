import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import 'auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _email = '';
  String _photoUrl = '';
  bool _loading = true;
  bool _busy = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    try {
      final d = await _auth.getProfile();
      _name.text = d?['name'] ?? '';
      _phone.text = d?['phone'] ?? '';
      _email = d?['email'] ?? _auth.currentUser?.email ?? '';
      _photoUrl = (d?['photoUrl'] ?? '').toString();
    } catch (e) {
      _snack('โหลดข้อมูลไม่สำเร็จ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: 512,
          maxHeight: 512);
      if (file == null) return;
      setState(() => _uploadingPhoto = true);
      final url = await CloudinaryService().uploadImage(file);
      final uid = _auth.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _photoUrl = url);
      _snack('เปลี่ยนรูปโปรไฟล์แล้ว');
    } on UploadException catch (e) {
      _snack(e.message);
    } on FirebaseException catch (e) {
      _snack('บันทึกรูปไม่สำเร็จ (${e.code})');
    } catch (e) {
      _snack('เปลี่ยนรูปไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _auth
          .updateProfile(name: _name.text.trim(), phone: _phone.text.trim())
          .timeout(const Duration(seconds: 10));
      _snack('บันทึกข้อมูลแล้ว');
    } on FirebaseAuthException catch (e) {
      _snack(AuthService.message(e));
    } catch (_) {
      _snack('บันทึกไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    String password = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบบัญชี'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ข้อมูลบัญชีจะถูกลบถาวร กรอกรหัสผ่านเพื่อยืนยัน'),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              onChanged: (v) => password = v,
              decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบบัญชี')),
        ],
      ),
    );
    if (ok != true) return;
    if (password.isEmpty) {
      _snack('กรุณากรอกรหัสผ่าน');
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await _auth.deleteAccount(password);
      // ปิดหน้านี้ แล้วแอปจะกลับหน้าล็อกอินเอง
      nav.popUntil((r) => r.isFirst);
      return;
    } on FirebaseAuthException catch (e) {
      _snack(AuthService.message(e));
    } catch (_) {
      _snack('ลบบัญชีไม่สำเร็จ ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _avatar() {
    return Center(
      child: Semantics(
        label: 'รูปโปรไฟล์',
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundImage:
                  _photoUrl.isNotEmpty ? NetworkImage(_photoUrl) : null,
              child: _photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 52)
                  : null,
            ),
            if (_uploadingPhoto)
              const SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(strokeWidth: 3)),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'เปลี่ยนรูปโปรไฟล์',
                icon: const Icon(Icons.camera_alt, size: 18),
                onPressed: (_busy || _uploadingPhoto) ? null : _changePhoto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลสมาชิก')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _avatar(),
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: _email,
                    enabled: false,
                    decoration: const InputDecoration(
                        labelText: 'อีเมล', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'ชื่อ', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'กรอกชื่อ' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'เบอร์โทร', border: OutlineInputBorder()),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      return RegExp(r'^[0-9]{9,10}$').hasMatch(t)
                          ? null
                          : 'เบอร์โทรต้องเป็นตัวเลข 9-10 หลัก';
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('บันทึกการแก้ไข'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('ลบบัญชี'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: _busy ? null : _delete,
                  ),
                ],
              ),
            ),
    );
  }
}