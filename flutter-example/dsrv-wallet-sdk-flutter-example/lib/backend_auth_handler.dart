import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';

/// 고객사 백엔드에 challenge 를 요청하는 AuthHandler.
/// 네이티브 example 의 `MyAuthHandler` 와 동일 계약: POST {backendUrl}/sdk/registration.
class BackendAuthHandler implements AuthHandler {
  final String backendUrl;
  BackendAuthHandler(this.backendUrl);

  @override
  Future<ChallengeResult> requestChallenge(ChallengeRequest request) async {
    try {
      final body = jsonEncode({
        'sdkId': request.sdkId,
        'appId': request.appId,
        'userCredential': {
          'type': request.userCredential.type.wireValue,
          'value': request.userCredential.value,
          'provider': request.userCredential.provider,
        },
        'deviceInfo': {
          'platform': request.deviceInfo.platform,
          'publicKey': request.deviceInfo.publicKey,
          'model': request.deviceInfo.model,
          'osVersion': request.deviceInfo.osVersion,
          'isVirtual': request.deviceInfo.isVirtual,
          // iOS 실기기는 App Attest attestationObject 가 필수 (Android 는 null → 무시됨)
          'attestationObject': request.deviceInfo.attestationObject,
        },
      });

      final url = '$backendUrl/sdk/registration';
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = json['data'] as Map<String, dynamic>?;
        final challenge = data?['challenge'] as String?;
        if (challenge != null && challenge.isNotEmpty) {
          return ChallengeResult.success(challenge);
        }
      }
      // 에러는 top-level message 또는 {error:{message}} 중첩 구조일 수 있음
      final nested = (json['error'] as Map?)?['message']?.toString();
      return ChallengeResult.failure(json['message']?.toString() ??
          nested ??
          'Challenge request failed (status ${resp.statusCode})');
    } catch (e) {
      return ChallengeResult.failure(e.toString());
    }
  }
}
