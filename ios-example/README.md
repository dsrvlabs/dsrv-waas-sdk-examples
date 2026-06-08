# DSRV Wallet SDK iOS Example

DSRV Wallet SDK 의 모든 기능을 시연하는 SwiftUI 샘플 앱입니다.

## 요구 사항
- Xcode 16.0 이상
- Swift 5.0 이상
- iOS 14.0 이상 (시뮬레이터 또는 실기기)
- macOS 14.0 이상 (개발 환경)

## 프로젝트 구조

```
dsrv-wallet-sdk-ios-example/
├── dsrv-wallet-sdk-ios-example/                # 앱 모듈
│   ├── dsrv_wallet_sdk_ios_exampleApp.swift    # 앱 진입점
│   ├── Models/                                 # 데이터 모델 / 비즈니스 로직
│   │   ├── Wallet.swift                        # ObservableObject ViewModel (모든 SDK 호출 핸들러)
│   │   ├── WalletHandlers.swift                # AuthHandler 구현 (challenge 요청)
│   │   ├── HttpHelper.swift                    # HTTP 통신 유틸
│   │   ├── TransferRepository.swift            # customer-backend /sdk/transfer/* 호출
│   │   ├── PaymentRepository.swift             # customer-backend /payments 호출
│   │   ├── TokenConfig.swift                   # chain 별 USDC 매핑
│   │   ├── BalanceClient.swift                 # RPC 잔액 조회
│   │   ├── Amount.swift                        # human ↔ base units 변환
│   │   └── ToastManager.swift                  # 토스트 메시지 관리
│   └── Views/
│       ├── Screens/
│       │   ├── RootView.swift                  # 루트 진입점 (Login | WalletList | WalletDetail | Feature)
│       │   └── WalletScreen.swift              # 메뉴 기반 다단계 화면
│       └── Components/
│           ├── SdkSection.swift                # initialize 호출 UI
│           ├── AccountSection.swift            # createAccount / getAccountList UI
│           ├── ChainSection.swift              # getChainList + chain 선택 UI
│           ├── TransferSection.swift           # 전송 UI (build → sign → broadcast)
│           ├── PaymentSection.swift            # Topup 결제 UI (POST /payments)
│           ├── DelegateSection.swift           # EIP-7702 delegate / revoke UI
│           ├── ApproveSection.swift            # 토큰 approve UI
│           ├── BackupSection.swift             # backup UI
│           ├── RestoreSection.swift            # restore UI
│           ├── LogSection.swift                # 실시간 로그
│           ├── QRScannerView.swift             # QR 스캔
│           ├── QRCodeView.swift                # QR 표시
│           ├── SectionCard.swift               # 카드형 컨테이너
│           └── CopyableText.swift              # 복사 가능한 텍스트
├── Frameworks/                                 # SDK 바이너리 (xcframework, 동봉)
│   ├── dsrv_wallet_sdk_ios.xcframework
│   └── Mpe.xcframework
├── dsrv-wallet-sdk-ios-example.xcodeproj/      # Xcode 프로젝트
└── Info.plist                                  # (필요 시) ATS 등 설정
```

> SDK 는 `Frameworks/` 에 **xcframework 바이너리**로 동봉됩니다 — `dsrv_wallet_sdk_ios.xcframework`(SDK 본체) + `Mpe.xcframework`(MPC 엔진). Xcode 가 Embed & Sign 으로 링크합니다.

---

## 환경 설정 (필수 — 실행 전 반드시 완료)

`Models/Wallet.swift` 의 `Config` 를 환경에 맞게 수정합니다:

```swift
public enum Config {
    /// 고객사 백엔드 서버 URL (AuthHandler 가 호출할 엔드포인트 베이스 URL)
    public static let customerBackendURL = "http://your-backend:3000"

    /// DSRV 에서 발급받은 SDK ID
    public static let sdkId = "your-sdk-id"

    /// DSRV API 베이스 URL. nil 이면 SDK 기본값 사용.
    public static let dsrvApiBaseUrl: String? = nil
}
```

> Bundle Identifier 도 SDK 등록 시 사용한 값과 일치시켜야 함. `dsrv-wallet-sdk-ios-example.xcodeproj` 의 build setting `PRODUCT_BUNDLE_IDENTIFIER`.

---

## 샘플 앱 실행 방법

### 1. 프로젝트 열기
```bash
open dsrv-wallet-sdk-ios-example.xcodeproj
```

### 2. 의존성 확인
- `Frameworks/dsrv_wallet_sdk_ios.xcframework`: SDK 본체 (Embed & Sign)
- `Frameworks/Mpe.xcframework`: MPC 네이티브 라이브러리 (Embed & Sign)
- `web3swift` (SwiftPM): Wei 변환, address 표시 등 부가 기능

### 3. 환경 설정
위의 **환경 설정** 섹션 참고.

### 4. 빌드 및 실행
1. 시뮬레이터(iPhone 17 등) 또는 실기기 선택
2. Product > Run (⌘R)

### 5. 사용
앱 시작 시 LoginScreen 에서 userId 입력 → SDK initialize → 메뉴 기반 화면 (지갑 조회 / 스마트어카운트 / 백업·복원 / 전송 / 결제 / 로그) 으로 진행.

> 전송 / 결제 흐름은 customer-backend 의 `/sdk/transfer/build-hash`, `/sdk/transfer/broadcast`, `/payments` 엔드포인트를 경유합니다. customer-backend 가 `X_API_KEY` 로 WaaS 와 직접 통신하므로 example 은 user token 을 보내지 않습니다.

---

## SDK 업데이트 방법

DSRV 에서 새 `dsrv_wallet_sdk_ios.xcframework` / `Mpe.xcframework` 를 받으면,
`Frameworks/` 의 기존 파일을 교체한 뒤 Xcode 에서 재빌드하면 됩니다.
