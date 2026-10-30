import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.createdAt,
  });

  factory AppNotification.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AppNotification(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      read: d['read'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class NotificationService {
  final _col = FirebaseFirestore.instance.collection('notifications');

  /// แจ้งเจ้าของร้าน (ถ้าแจ้งไม่สำเร็จ ไม่ให้กระทบงานหลัก)
  Future<void> notifyOwner(String title, String body) =>
      _add({'toRole': 'owner', 'title': title, 'body': body});

  /// แจ้งผู้ใช้รายคน
  Future<void> notifyUser(String uid, String title, String body) =>
      _add({'toUid': uid, 'title': title, 'body': body});

  Future<void> _add(Map<String, dynamic> data) async {
    try {
      await _col.add({
        ...data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Query<Map<String, dynamic>> _mine(bool isOwner) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return isOwner
        ? _col.where('toRole', isEqualTo: 'owner')
        : _col.where('toUid', isEqualTo: uid);
  }

  Stream<List<AppNotification>> watch(bool isOwner) =>
      _mine(isOwner).snapshots().map((s) {
        final list = s.docs.map(AppNotification.fromDoc).toList();
        final now = DateTime.now();
        list.sort((a, b) =>
            (b.createdAt ?? now).compareTo(a.createdAt ?? now));
        return list;
      });

  Stream<int> unreadCount(bool isOwner) => _mine(isOwner)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead(List<AppNotification> list) {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in list.where((n) => !n.read)) {
      batch.update(_col.doc(n.id), {'read': true});
    }
    return batch.commit();
  }
}