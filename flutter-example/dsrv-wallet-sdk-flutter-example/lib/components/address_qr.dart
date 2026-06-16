import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Android `QRCodeView.kt` / iOS `QRCodeView.swift` 대응 — 주소 등 문자열을
/// 스캔 가능한 QR 코드로 렌더링. 흰 배경 + 패딩으로 명암 대비를 확보한다.
class AddressQr extends StatelessWidget {
  final String content;
  final double size;
  const AddressQr({super.key, required this.content, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: QrImageView(
        data: content,
        size: size,
        backgroundColor: Colors.white,
      ),
    );
  }
}
