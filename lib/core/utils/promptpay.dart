/// สร้างข้อความ PromptPay QR (มาตรฐาน EMVCo) แบบระบุเบอร์โทรและยอดเงิน
String promptPayPayload(String phone, double amount) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final target = '0066829670971${digits.substring(1)}'; // 0812345678 -> 0066812345678

  String f(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

  final merchant = f('00', 'A000000677010111') + f('01', target);
  final data = f('00', '01') +
      f('01', '12') + // 12 = QR แบบระบุยอด
      f('29', merchant) +
      f('53', '764') + // สกุลเงินบาท
      f('54', amount.toStringAsFixed(2)) +
      f('58', 'TH') +
      '6304';
  return data + _crc16(data);
}

String _crc16(String s) {
  var crc = 0xFFFF;
  for (final b in s.codeUnits) {
    crc ^= b << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}