import 'package:flutter/material.dart';

/// เปิดดูรูปสลิปเต็มจอ ซูมได้
void showSlip(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              semanticLabel: 'รูปสลิปการโอนเงิน',
              loadingBuilder: (c, child, prog) => prog == null
                  ? child
                  : const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => const SizedBox(
                  height: 160,
                  child: Center(child: Text('โหลดรูปสลิปไม่สำเร็จ'))),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filled(
              tooltip: 'ปิด',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}