# DSRV Wallet SDK Examples

DSRV Wallet SDK(MPC 기반 비수탁 지갑)를 **Android · iOS · Flutter** 에서 통합하는 방법을 보여주는 예제 모음입니다.
지갑 앱과, 앱이 의존하는 **고객사 백엔드(customer-backend)** 예제를 함께 제공합니다.

## 구성

| 디렉토리 | 설명 | 스택 | 문서 |
|----------|------|------|------|
| [`customer-backend`](customer-backend) | DSRV WaaS Gateway 프록시 서버 — SDK 등록 / 전송 / 결제 / 거래내역을 서버키로 중계 | NestJS (Node.js) | [README](customer-backend/backend/README.md) |
| [`android-example`](android-example) | Android 지갑 샘플 앱 | Kotlin · Jetpack Compose | [README](android-example/README.md) |
| [`ios-example`](ios-example) | iOS 지갑 샘플 앱 | Swift · SwiftUI | [README](ios-example/README.md) |
| [`flutter-example`](flutter-example) | Flutter 플러그인 + 샘플 앱 | Dart · Flutter | [앱](flutter-example/dsrv-wallet-sdk-flutter-example/README.md) · [플러그인](flutter-example/dsrv-wallet-sdk-flutter/README.md) |

> SDK 는 소스가 아닌 **바이너리**로 동봉됩니다.

## 아키텍처

```
  지갑 앱  (Android / iOS / Flutter + SDK 바이너리)
        │
        │  HTTP  — challenge / 전송 build·broadcast / 결제 / 거래내역
        ▼
  customer-backend  (고객사 서버)
        │
        │  x-api-key
        ▼
  DSRV WaaS Gateway  (Auth / WaaS / Payments)
```

- **지갑 앱**: SDK 로 MPC 지갑 생성·서명을 디바이스에서 직접 수행. 민감한 사용자 토큰을 들고 다니지 않습니다.
- **customer-backend**: 고객사가 운영하는 서버. 자체 `X_API_KEY` 로 DSRV Gateway 를 호출해 SDK 등록·전송 build/broadcast·결제·거래내역을 중계합니다.
- **DSRV WaaS Gateway**: `x-api-key` 를 `X-User-Passport` JWT 로 변환해 Auth/WaaS/Payments 로 전달.

## 공통 설정값

세 example 앱이 공유하는 값입니다. DSRV 에서 발급받아 채워주세요.

| 키 | 설명 |
|----|------|
| `SDK_ID` | DSRV 에서 발급받은 SDK ID |
| `CUSTOMER_BACKEND_URL` | 실행 중인 `customer-backend` 주소 (앱이 challenge·전송·결제·거래내역 요청) |
| `DSRV_API_BASE_URL` | DSRV WaaS Gateway 베이스 URL |

플랫폼별 주입 위치:

| 플랫폼 | 위치 |
|--------|------|
| Android | `android-example/gradle.properties` |
| iOS | `ios-example/.../Models/Wallet.swift` 의 `Config` |
| Flutter | `flutter-example/.../lib/config.dart` 또는 `--dart-define` |
| customer-backend | `customer-backend/backend/.env` (`.env.sample` 복사) |

## 빠른 시작

### 1. customer-backend 실행

```bash
cd customer-backend/backend
cp .env.sample .env        # SDK_ID / X_API_KEY / CUSTOMER_PRIVATE_KEY / DSRV_API_BASE_URL 채우기
make run                   # http://localhost:3000
```

### 2. 지갑 앱 실행 (원하는 플랫폼)

각 example README 의 안내대로 공통 설정값을 채우고 실행합니다.
- 에뮬레이터/시뮬레이터에서 로컬 customer-backend 에 붙으려면 Android 는 `http://10.0.2.2:3000`, iOS 시뮬레이터는 `http://localhost:3000` 을 사용하세요.

```bash
# Android
cd android-example && ./gradlew :app:installDebug

# iOS
open ios-example/dsrv-wallet-sdk-ios-example.xcodeproj

# Flutter
cd flutter-example/dsrv-wallet-sdk-flutter-example && flutter run
```

## 제공 기능

모든 플랫폼 example 이 동일한 흐름을 시연합니다:

1. **초기화** — userId 입력 → SDK initialize (AuthHandler 로 challenge 교환)
2. **계정 / 지갑 생성** — `createAccount` → `createAddress` (MPC 키 생성)
3. **전송** — customer-backend 경유 build → 디바이스 MPC sign → broadcast
4. **결제 (Topup)** — customer-backend `POST /payments`
5. **스마트어카운트** — EIP-7702 위임(delegate) · 토큰 승인(approve)
6. **백업 / 복원** — OS 클라우드(iCloud / Block Store) 기반
7. **거래 내역** — customer-backend `GET /sdk/transactions`

## 요구사항

| 플랫폼 | 요구사항 |
|--------|----------|
| customer-backend | Node.js `>=24`, pnpm |
| Android | JDK 17, Android SDK (minSdk 26) |
| iOS | Xcode 16+, iOS 14.0+ |
| Flutter | Flutter 3.x, Dart 3.x |

## 문의

기술 지원이 필요하시면 DSRV 개발팀에 문의해 주세요.
