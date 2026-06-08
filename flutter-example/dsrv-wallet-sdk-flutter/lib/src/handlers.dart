/// 인증 핸들러 및 관련 타입 — native AuthHandler 와 1:1.
///
/// native `DSRVWallet.initialize` 가 challenge 를 요청하면, 브릿지가 이 Dart
/// AuthHandler 로 역방향 호출(MethodChannel `onRequestChallenge`)한다.

enum CredentialType {
  userId('USER_ID'),
  oauthToken('OAUTH_TOKEN'),
  idpToken('IDP_TOKEN');

  final String wireValue;
  const CredentialType(this.wireValue);

  static CredentialType fromWire(String value) =>
      CredentialType.values.firstWhere(
        (e) => e.wireValue == value,
        orElse: () => CredentialType.userId,
      );
}

/// 사용자 인증 정보.
class UserCredential {
  final CredentialType type;
  final String value;
  final String provider;

  const UserCredential({
    required this.type,
    required this.value,
    this.provider = '',
  });
}

/// 디바이스 정보 (native 가 채워 challenge 요청에 포함).
class DeviceInfo {
  final String? keyId;
  final String? publicKey;
  final String model;
  final String osVersion;
  final bool isVirtual;
  final String? attestationObject;
  final String platform; // "IOS" / "ANDROID"

  const DeviceInfo({
    this.keyId,
    this.publicKey,
    required this.model,
    required this.osVersion,
    required this.isVirtual,
    this.attestationObject,
    required this.platform,
  });

  factory DeviceInfo.fromMap(Map<dynamic, dynamic> map) => DeviceInfo(
        keyId: map['keyId'] as String?,
        publicKey: map['publicKey'] as String?,
        model: (map['model'] as String?) ?? '',
        osVersion: (map['osVersion'] as String?) ?? '',
        isVirtual: (map['isVirtual'] as bool?) ?? false,
        attestationObject: map['attestationObject'] as String?,
        platform: (map['platform'] as String?) ?? '',
      );
}

/// challenge 요청 컨텍스트.
class ChallengeRequest {
  final String sdkId;
  final String appId;
  final UserCredential userCredential;
  final DeviceInfo deviceInfo;

  const ChallengeRequest({
    required this.sdkId,
    required this.appId,
    required this.userCredential,
    required this.deviceInfo,
  });

  factory ChallengeRequest.fromMap(Map<dynamic, dynamic> map) =>
      ChallengeRequest(
        sdkId: (map['sdkId'] as String?) ?? '',
        appId: (map['appId'] as String?) ?? '',
        userCredential: UserCredential(
          type: CredentialType.fromWire(
              (map['credentialType'] as String?) ?? 'USER_ID'),
          value: (map['credentialValue'] as String?) ?? '',
          provider: (map['provider'] as String?) ?? '',
        ),
        deviceInfo:
            DeviceInfo.fromMap((map['deviceInfo'] as Map?) ?? const {}),
      );
}

/// challenge 교환 결과.
class ChallengeResult {
  final bool success;
  final String? challenge;
  final String? error;

  const ChallengeResult.success(this.challenge)
      : success = true,
        error = null;

  const ChallengeResult.failure(this.error)
      : success = false,
        challenge = null;
}

/// 고객사 백엔드와 challenge 를 교환하는 핸들러.
/// 앱이 구현해 `DSRVWallet.initialize` 에 전달한다.
abstract class AuthHandler {
  Future<ChallengeResult> requestChallenge(ChallengeRequest request);
}
