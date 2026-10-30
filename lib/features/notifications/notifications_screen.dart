import 'package:flutter/material.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  final bool isOwner;
  const NotificationsScreen({super.key, required this.isOwner});

  String _time(DateTime? t) {
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return StreamBuilder<List<AppNotification>>(
      stream: service.watch(isOwner),
      builder: (context, snap) {
        final list = snap.data ?? [];
        Widget body;
        if (snap.hasError) {
          body = const Center(child: Text('โหลดการแจ้งเตือนไม่สำเร็จ'));
        } else if (!snap.hasData) {
          body = const Center(child: CircularProgressIndicator());
        } else if (list.isEmpty) {
          body = const Center(child: Text('ยังไม่มีการแจ้งเตือน'));
        } else {
          body = ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = list[i];
              return ListTile(
                leading: Icon(
                  n.read ? Icons.notifications_none : Icons.notifications_active,
                  color: n.read ? null : Theme.of(context).colorScheme.primary,
                ),
                title: Text(n.title,
                    style: TextStyle(
                        fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text('${n.body}\n${_time(n.createdAt)}'),
                isThreeLine: true,
                trailing: n.read
                    ? null
                    : const Icon(Icons.circle, size: 10, color: Colors.redAccent),
                onTap: n.read ? null : () => service.markRead(n.id),
              );
            },
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('การแจ้งเตือน'),
            actions: [
              TextButton(
                onPressed: list.any((n) => !n.read)
                    ? () => service.markAllRead(list)
                    : null,
                child: const Text('อ่านทั้งหมด'),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }
}