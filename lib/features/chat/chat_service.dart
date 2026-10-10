import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final bool isOwner;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.isOwner,
    this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      text: d['text'] ?? '',
      senderId: d['senderId'] ?? '',
      isOwner: d['isOwner'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ChatService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _room(String roomId) =>
      _db.collection('chats').doc(roomId);

  Stream<List<ChatMessage>> watchMessages(String roomId) => _room(roomId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  /// ห้องแชททั้งหมด (สำหรับเจ้าของร้าน) เรียงตามข้อความล่าสุด
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms() => _db
      .collection('chats')
      .orderBy('updatedAt', descending: true)
      .snapshots();

  Future<void> send({
    required String roomId,
    required String text,
    required bool isOwner,
  }) {
    final user = FirebaseAuth.instance.currentUser!;
    final batch = _db.batch();
    batch.set(_room(roomId).collection('messages').doc(), {
      'text': text,
      'senderId': user.uid,
      'isOwner': isOwner,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final roomData = <String, dynamic>{
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!isOwner) {
      roomData['customerName'] = user.displayName ?? user.email ?? 'ลูกค้า';
    }
    batch.set(_room(roomId), roomData, SetOptions(merge: true));
    return batch.commit();
  }
}