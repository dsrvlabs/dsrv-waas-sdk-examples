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

  /// 잔액 조회 / 읽기 전용 호출용 공용 RPC 엔드포인트 — chainId 별.
  /// 환경(dev/staging/prod) 분리·장애 대응을 위해 `--dart-define` 으로 덮어쓸 수 있다:
  ///   --dart-define=RPC_URL_1=https://my-mainnet-rpc
  static const Map<String, String> rpcUrls = {
    '11155111': String.fromEnvironment(
      'RPC_URL_11155111',
      defaultValue: 'https://ethereum-sepolia-rpc.publicnode.com',
    ),
    '84532': String.fromEnvironment(
      'RPC_URL_84532',
      defaultValue: 'https://sepolia.base.org',
    ),
    '1': String.fromEnvironment(
      'RPC_URL_1',
      defaultValue: 'https://ethereum-rpc.publicnode.com',
    ),
    '8453': String.fromEnvironment(
      'RPC_URL_8453',
      defaultValue: 'https://mainnet.base.org',
    ),
  };
}
