# DSRV Wallet SDK Flutter Example

DSRV Wallet SDK 의 모든 기능을 시연하는 Flutter 샘플 앱입니다.
SDK 는 옆 디렉토리의 플러그인(`../dsrv-wallet-sdk-flutter`)을 `path` 의존으로 참조하며,
네이티브는 **바이너리로 동봉**되어 있습니다 (Android=난독화 AAR, iOS=xcframework).

## 요구 사항
- Flutter 3.x 이상
- Dart 3.x 이상
- Android: minSdk 26, `FlutterFragmentActivity` 필요 (백업/Passkey)
- iOS: 14.0 이상

## 프로젝트 구조

```
dsrv-wallet-sdk-flutter-example/
├── lib/
│   ├── main.dart                    # 앱 진입점
│   ├── config.dart                  # SDK_ID / CUSTOMER_BACKEND_URL / DSRV_API_BASE_URL
│   ├── user_session.dart            # userId ↔ UUID v3 (cross-platform 결정적)
│   ├── wallet_state.dart            # ChangeNotifier (모든 SDK 호출 핸들러)
│   ├── backend_auth_handler.dart    # AuthHandler 구현
│   ├── token_config.dart            # chain 별 USDC 매핑
│   ├── transfer_repository.dart     # customer-backend /sdk/transfer/* 호출
│   ├── payment_repository.dart      # customer-backend /payments 호출
│   ├── ui.dart                      # 공용 위젯 (SectionCard / AsyncButton / KeyValueRow / …)
│   ├── screens/
│   │   ├── root_screen.dart         # 네비게이션 (Login→WalletList→WalletDetail→Feature)
│   │   ├── login_screen.dart        # userId 입력 + UUID 미리보기 + SDK 초기화
│   │   ├── wallet_list_screen.dart  # 체인 선택 + 계정/지갑 선택
│   │   ├── wallet_detail_screen.dart# 지갑 요약 + 기능 메뉴
│   │   └── feature_screen.dart      # 기능별 화면 (조회/스마트어카운트/백업/전송/결제/로그)
│   └── components/
│       ├── chain_section.dart       # 체인 목록 / 선택
│       ├── account_section.dart     # createAccount / getAccountList / create
│       ├── delegate_section.dart    # EIP-7702 delegate / revoke
│       ├── approve_section.dart     # 결제 토큰 approve
│       ├── transfer_section.dart    # 전송 (customer-backend 경유 build/broadcast)
│       ├── payment_section.dart     # Topup 결제 (POST /payments)
│       ├── backup_section.dart      # 백업 + debug
│       ├── restore_section.dart     # 복원
│       └── log_section.dart         # 실시간 로그
└── pubspec.yaml                     # dsrv_wallet_sdk: { path: ../dsrv-wallet-sdk-flutter }
```

## 환경 설정

`lib/config.dart` 의 `AppConfig` 기본값을 발급받은 값으로 교체하거나, 실행 시 `--dart-define` 으로 주입합니다.

```bash
flutter run \
  --dart-define=SDK_ID=your-sdk-id \
  --dart-define=CUSTOMER_BACKEND_URL=https://your-backend.com \
  --dart-define=DSRV_API_BASE_URL=https://api.dsrv.com
```

> 에뮬레이터에서 호스트의 로컬 customer-backend 에 붙으려면 `CUSTOMER_BACKEND_URL=http://10.0.2.2:3000` (10.0.2.2 = 에뮬레이터→호스트 alias) 을 사용하세요.

## 실행

```bash
flutter pub get
flutter run        # 연결된 Android/iOS 기기 또는 에뮬레이터
```

화면 흐름 (Android/iOS 네이티브 example 과 동일):

```
Login              userId 입력 → 결정적 UUID 생성 → SDK 초기화
└─ 지갑 선택        체인 선택 + 계정/지갑 선택
   └─ 지갑 상세      선택된 지갑 요약 + 기능 메뉴
      └─ 기능        조회 / 스마트어카운트 / 백업·복원 / 전송 / 결제 / 로그
```

전송·결제는 customer-backend 의 `/sdk/transfer/build-hash` · `/sdk/transfer/broadcast` · `/payments` 를 경유합니다. customer-backend 가 `X_API_KEY` 로 WaaS 와 직접 통신하므로 example 은 user token 을 보내지 않으며, MPC sign 만 디바이스가 `DSRVWallet.sign()` 으로 직접 수행합니다.

## SDK 바이너리

이 example 은 SDK 를 소스가 아닌 **바이너리로** 사용합니다. 별도 빌드/동기화 단계는 필요 없습니다.

- **Android**: `../dsrv-wallet-sdk-flutter/android/repo/` 에 난독화 AAR (`com.dsrv.wallet:sdk`) 이 로컬 maven 저장소로 동봉되어 있고, 플러그인 `build.gradle` 이 이를 참조합니다.
- **iOS**: `../dsrv-wallet-sdk-flutter/ios/Frameworks/` 에 `dsrv_wallet_sdk_ios.xcframework` + `Mpe.xcframework` 가 동봉되어 있고, podspec 이 vendored framework 로 링크합니다.

새 SDK 버전을 받으면 위 경로의 바이너리만 교체하면 됩니다.
