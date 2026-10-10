import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'chat_service.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แชทลูกค้า')),
      body: StreamBuilder(
        stream: ChatService().watchRooms(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('โหลดแชทไม่สำเร็จ'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rooms = snap.data!.docs;
          if (rooms.isEmpty) {
            return const Center(child: Text('ยังไม่มีแชทจากลูกค้า'));
          }
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, i) {
              final d = rooms[i].data();
              final name = (d['customerName'] ?? 'ลูกค้า') as String;
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: Text(
                  (d['lastMessage'] ?? '') as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        roomId: rooms[i].id, title: name, isOwner: true),
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