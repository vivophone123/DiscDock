import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/email_config.dart';

class EmailService {
  static bool get _configured =>
      !emailJsServiceId.contains('xxx') &&
      !emailJsTemplateId.contains('xxx') &&
      !emailJsPublicKey.contains('xxx');

  /// ส่งอีเมล คืน true ถ้าสำเร็จ
  /// ไม่โยน error เพราะอีเมลล้มเหลวต้องไม่กระทบการสั่งซื้อ
  static Future<bool> send({
    required String to,
    required String subject,
    required String message,
  }) async {
    if (!_configured || to.trim().isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service_id': emailJsServiceId,
              'template_id': emailJsTemplateId,
              'user_id': emailJsPublicKey,
              'template_params': {
                'to_email': to.trim(),
                'subject': subject,
                'message': message,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}