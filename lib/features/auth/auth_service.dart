import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(name);
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'email': email,
      'phone': '',
      'role': 'customer',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> logout() => _auth.signOut();

  /// อ่านข้อมูลโปรไฟล์จาก Firestore
  Future<Map<String, dynamic>?> getProfile() async {
    final doc =
        await _db.collection('users').doc(_auth.currentUser!.uid).get();
    return doc.data();
  }

  /// แก้ไขชื่อและเบอร์โทร (Update)
  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final user = _auth.currentUser!;
    await user.updateDisplayName(name);
    await _db.collection('users').doc(user.uid).update({
      'name': name,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ลบบัญชี (Delete) ต้องยืนยันรหัสผ่านก่อน
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser!;
    final cred =
        EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
    await _db.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  /// แปลง error code ของ Firebase เป็นข้อความภาษาไทย
  static String message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครแล้ว';
      case 'weak-password':
        return 'รหัสผ่านสั้นเกินไป (อย่างน้อย 6 ตัว)';
      case 'network-request-failed':
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';
      case 'too-many-requests':
        return 'ลองบ่อยเกินไป กรุณารอสักครู่';
      case 'requires-recent-login':
        return 'กรุณาล็อกอินใหม่ แล้วลองอีกครั้ง';
      default:
        return 'เกิดข้อผิดพลาด (${e.code})';
    }
  }
}