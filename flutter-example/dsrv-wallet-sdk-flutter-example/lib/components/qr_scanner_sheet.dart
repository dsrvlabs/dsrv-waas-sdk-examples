import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// `ethereum:0x…@chainId/…?…` 같은 EIP-681 URI 에서 순수 address 만 추출.
/// Android `parseRecipient` / iOS `parseRecipient` 와 동일한 규칙:
/// "ethereum:" 접두사를 제거한 뒤 '@', '/', '?' 앞부분만 취한다.
String parseRecipient(String raw) {
  final trimmed = raw.trim();
  if (trimmed.toLowerCase().startsWith('ethereum:')) {
    final rest = trimmed.substring('ethereum:'.length);
    return rest.split('@').first.split('/').first.split('?').first;
  }
  return trimmed;
}

/// Android `QRScannerView.kt` / iOS `QRScannerSheet` 대응 — 카메라로 QR 을 스캔해
/// 첫 디코딩 문자열을 반환하고 닫힌다. 닫기 버튼으로 취소 시 null 반환.
class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({super.key});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        if (!mounted) return;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '카메라를 사용할 수 없습니다',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '설정에서 카메라 권한을 허용해 주세요.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스캐너를 풀스크린으로 띄우고 파싱된 recipient 주소를 반환한다. 취소 시 null.
Future<String?> scanRecipient(BuildContext context) async {
  final scanned = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const QrScannerSheet(),
    ),
  );
  if (scanned == null) return null;
  return parseRecipient(scanned);
}
