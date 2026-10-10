import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/constants/cloudinary_config.dart';

class UploadException implements Exception {
  final String message;
  UploadException(this.message);
  @override
  String toString() => message;
}

class CloudinaryService {
  /// อัปโหลดรูป 1 รูป คืนค่าเป็นลิงก์ https
  Future<String> uploadImage(XFile file) async {
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');
    try {
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final res = await req.send().timeout(const Duration(seconds: 30));
      final body = await res.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        final msg = json['error']?['message'] ?? 'รหัส ${res.statusCode}';
        throw UploadException('อัปโหลดรูปไม่สำเร็จ: $msg');
      }
      return json['secure_url'] as String;
    } on TimeoutException {
      throw UploadException('อัปโหลดรูปนานเกินไป ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่');
    } on SocketException {
      throw UploadException('เชื่อมต่ออินเทอร์เน็ตไม่ได้ อัปโหลดรูปไม่ได้');
    }
  }
}