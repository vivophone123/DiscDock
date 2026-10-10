import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import 'chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String title;
  final bool isOwner; // true = เจ้าของร้านกำลังตอบ

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.title,
    required this.isOwner,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _cloud = CloudinaryService();
  final _input = TextEditingController();
  final _myUid = FirebaseAuth.instance.currentUser!.uid;
  bool _uploading = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    // ไม่ await เพราะถ้าออฟไลน์ข้อความจะค้างในเครื่องแล้วซิงก์ทีหลัง
    _service
        .send(roomId: widget.roomId, text: text, isOwner: widget.isOwner)
        .catchError((e) => _showError('ส่งไม่สำเร็จ: $e'));
  }

  Future<void> _sendImage() async {
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 1280);
      if (file == null) return;
      setState(() => _uploading = true);
      final url = await _cloud.uploadImage(file);
      await _service.send(
          roomId: widget.roomId, imageUrl: url, isOwner: widget.isOwner);
    } on UploadException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('ส่งรูปไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _service.watchMessages(widget.roomId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('โหลดแชทไม่สำเร็จ'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!.reversed.toList();
                if (msgs.isEmpty) {
                  return const Center(
                      child: Text('ยังไม่มีข้อความ ลองทักทายเลย'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.senderId == _myUid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(8),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mine
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: m.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  m.imageUrl!,
                                  width: 200,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (c, child, prog) =>
                                      prog == null
                                          ? child
                                          : const SizedBox(
                                              width: 200,
                                              height: 120,
                                              child: Center(
                                                  child:
                                                      CircularProgressIndicator())),
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 200,
                                      height: 80,
                                      child: Center(
                                          child: Text('โหลดรูปไม่สำเร็จ'))),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Text(m.text),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_uploading) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _uploading ? null : _sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}