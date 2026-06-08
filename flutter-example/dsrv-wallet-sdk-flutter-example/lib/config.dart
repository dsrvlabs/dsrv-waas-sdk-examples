/// 데모 설정 — 네이티브 example 의 gradle.properties / Config 구조체에 대응.
///
/// 아래 기본값을 발급받은 값으로 교체하거나, 빌드/실행 시 `--dart-define` 으로 덮어쓸 수 있다:
///   flutter run \
///     --dart-define=SDK_ID=your-sdk-id \
///     --dart-define=CUSTOMER_BACKEND_URL=https://your-backend.com \
///     --dart-define=DSRV_API_BASE_URL=https://api.dsrv.com
class AppConfig {
  /// DSRV 에서 발급받은 SDK ID
  static const String sdkId =
      String.fromEnvironment('SDK_ID', defaultValue: 'your-sdk-id');

  /// 고객사 백엔드 (challenge 발급)
  static const String customerBackendUrl = String.fromEnvironment(
    'CUSTOMER_BACKEND_URL',
    defaultValue: 'https://your-backend.com',
  );

  /// DSRV WaaS API base URL (비우면 SDK 기본값)
  static const String dsrvApiBaseUrl = String.fromEnvironment(
    'DSRV_API_BASE_URL',
    defaultValue: 'https://api.dsrv.com',
  );
}
