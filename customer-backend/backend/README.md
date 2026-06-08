# Customer Backend

DSRV Wallet SDK의 고객 백엔드 서비스입니다. NestJS 프레임워크로 구축되었습니다.

## 기술 스택

- **Node.js** `>=24`
- **NestJS** 11
- **pnpm** 11.3.0 (`packageManager` 필드로 버전 고정)

## 사전 준비

`pnpm` 이 필요합니다. 다음 중 한 가지 방법으로 설치하세요.

```bash
# corepack 사용 (Node 에 포함된 경우)
corepack enable

# 또는 npm 으로 직접 설치
npm install -g pnpm@11.3.0
```

## 프로젝트 구조

```
src/
├── auth/           # SDK 등록 (POST /sdk/registration → DSRV Auth via Gateway)
├── transfer/       # SDK transfer proxy (POST /sdk/transfer/build-hash, /broadcast → WaaS via Gateway)
├── payment/        # Topup 결제 (POST /payments → stablecoin Payments via Gateway)
├── health/         # 헬스 체크
├── well-known/     # Passkey 도메인 검증 (AASA / assetlinks)
├── common/         # 공통 유틸리티 (인터셉터, 필터)
├── app.module.ts   # 메인 앱 모듈
└── main.ts         # 애플리케이션 엔트리포인트
```

## 환경 설정

`.env.sample` 파일을 복사하여 `.env` 파일을 생성합니다.

```bash
cp .env.sample .env
```

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `PORT` | 서버 실행 포트 | `3000` |
| `DSRV_API_BASE_URL` | DSRV Gateway 베이스 URL (host only — WaaS/Payments 공용) | `https://api-gw.dev.dsrv.com` |
| `X_API_KEY` | DSRV API 키 — Gateway 가 `X-User-Passport` JWT 로 변환 | - |
| `CUSTOMER_PRIVATE_KEY` | 고객사 EOA 개인키 — `paymentDigest` ECDSA 서명 전용 | - |

## 실행 방법

```bash
# 1. 환경 변수 준비 — .env.sample 을 복사해 값을 채웁니다
cp .env.sample .env

# 2. 서버 실행 (의존성 설치 + NestJS 기동)
make run
```

[사전 준비](#사전-준비)의 `pnpm` 이 설치돼 있어야 합니다. 서버는 기본적으로
`http://localhost:3000` 에서 동작합니다.

## API 엔드포인트

서버 실행 시 `http://localhost:3000`에서 접근할 수 있습니다.

### `POST /sdk/registration`

SDK 디바이스를 인증하고 DSRV WaaS에 등록합니다.

**Request (Android)**
```json
{
  "sdkId": "string",
  "appId": "string",
  "userCredential": { "type": "USER_ID", "value": "string", "provider": "string" },
  "signingHash": "string",
  "deviceInfo": {
    "platform": "ANDROID",
    "publicKey": "string",
    "model": "string",
    "osVersion": "string",
    "isVirtual": false
  }
}
```

**Request (iOS)**
```json
{
  "sdkId": "string",
  "appId": "string",
  "userCredential": { "type": "USER_ID", "value": "string", "provider": "string" },
  "deviceInfo": {
    "platform": "IOS",
    "publicKey": "string",
    "attestationObject": "string",
    "model": "string",
    "osVersion": "string",
    "isVirtual": false
  }
}
```

**Response**
```json
{
  "challenge": "string",
  "expiredIn": 3000
}
```

### `POST /sdk/transfer/build-hash`

SDK example 의 build 단계 — customer-backend 가 자체 `x-api-key (X_API_KEY)` 로 WaaS 의 `POST /waas/api/v1/transactions/ncw/transfer/build` 를 호출. WaaS 의 batch shape (`items[] + atomic`) 을 단건 형태로 변환해 반환.

**Request**
```json
{
  "fromAddress": "0x... (40 hex)",
  "toAddress": "0x... (40 hex)",
  "amount": "1000000",      // wei, 정수 문자열
  "chainId": "11155111",    // string
  "contractAddress": "0x..." // ERC-20 일 때만, 없으면 native
}
```

**Response**
```json
{
  "txId": "BTX-...",        // broadcast 시 path 파라미터
  "signId": "TX-... 또는 EXE-...",  // sign 의 signId 자리에 사용
  "messageHash": "0x... (keccak256)",
  "type": "TRANSACTION | CONTRACT_CALL"
}
```

### `POST /sdk/transfer/broadcast`

SDK example 의 broadcast 단계 — customer-backend 가 WaaS 의 `POST /waas/api/v1/transactions/ncw/{batchTxId}/broadcast` 를 호출해 체인에 전파.

**Request**
```json
{
  "txId": "BTX-..."
}
```

**Response**
```json
{
  "txHash": "0x... (체인 트랜잭션 해시) | null (EIP-7702 bundler 경로면 null)",
  "status": "BROADCAST | SIGNED | ...",
  "batchTxId": "BTX-..."
}
```

`txHash` 가 `null` 인 경우 (status=`SIGNED`) 는 bundler 가 비동기로 onchain 전송 — `batchTxId` 로 후속 polling.

### `POST /payments`

Topup 결제 단일 진입점. 내부에서 stablecoin Payments `quote → paymentDigest 서명 (고객사 PK) → execute` 를 순차 처리하므로 클라이언트는 서명을 첨부하지 않음.

**Request**
```json
{
  "sourceUserId": "string",  // Payments external_user_ref (RN 앱 로그인 ID)
  "chainId": 84532,          // EVM chainId (정수)
  "token": "0x... (40 hex)",  // ERC-20 컨트랙트
  "from": "0x... (40 hex)",   // NCW (smart account) 주소
  "to":   "0x... (40 hex)",   // SETTLEMENT 지갑
  "amount": "1.5",           // humanized (예: "1.5", "100") — wei 변환은 stablecoin Payments 가 담당
  "paymentType": 0           // 0 = 일반 결제
}
```

**Response**
```json
{
  "transactionId": "TX-...",
  "paymentUuid": "0x...",
  "status": "SUBMITTED",
  "txHash": "0x... | null (EIP-7702 bundler 경로면 null)",
  "submittedAt": "2026-..."
}
```

`DSRV_API_BASE_URL`, `X_API_KEY`, `CUSTOMER_PRIVATE_KEY` env 가 필요 (부팅 시 `getOrThrow` 검증).

### `GET /api/health`

헬스 체크. plain text `ok` 반환.

### `GET /.well-known/apple-app-site-association`

iOS Passkey 도메인 검증용 AASA 파일을 반환합니다 (`application/json`).
값을 수정하려면 `src/well-known/apple-app-site-association`을 직접 편집 후 재빌드합니다.

### `GET /.well-known/assetlinks.json`

Android Digital Asset Links 파일을 반환합니다 (`application/json`).
값을 수정하려면 `src/well-known/assetlinks.json`을 직접 편집 후 재빌드합니다.

## Make Commands

`Makefile`이 제공하는 인터페이스입니다.

| Command | 설명 |
|---------|------|
| `make run` | 의존성 설치 후 서버 실행 (`.env` 설정을 읽음) |
| `make install` | 의존성 설치 (`pnpm install`) |
| `make build` | NestJS 프로덕션 빌드 (`dist/main.js`) |
| `make clean` | `dist/` 및 `node_modules/` 정리 |

## License

UNLICENSED
