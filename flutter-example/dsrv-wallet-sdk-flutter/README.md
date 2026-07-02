# DSRV Wallet SDK for Flutter

DSRV MPC 지갑 기능을 제공하는 Flutter 플러그인입니다.

## 아키텍처 — 네이티브 브릿지

이 플러그인은 로직을 Dart 에서 재구현하지 않고, **이미 완성된 native `DSRVWallet` SDK**(Android AAR / iOS xcframework)에 **MethodChannel** 로 위임합니다.

```
Dart (thin API/모델)            Native plugin                 Native SDK
DSRVWallet.transfer(...) ─invoke─▶ handle("transfer") ────────▶ DSRVWallet.transfer(...)
AuthHandler(Dart)        ◀invoke── AuthHandler.requestChallenge (역방향 콜백)
```

- 채널: `com.dsrv.wallet.sdk/api`
- 백업/Passkey/생체인증/MPC = native 그대로 동작 (iOS iCloud Keychain, Android Google Drive)
- iOS Swift 6 / Android 동시성 수정 등 native 개선사항을 자동 상속

## 셋업 요구사항

### Android
- 플러그인은 native SDK 를 **난독화 AAR** 로 동봉합니다 (자족적 패키지, 별도 빌드 불필요):
  - `android/repo/com/dsrv/wallet/sdk/<version>/sdk-<version>.aar` — 난독화된 SDK (native `libmpe.so` / `libmpe_jni.so` 포함)
  - `android/repo/.../sdk-<version>.pom` — SDK 런타임 의존성(sqlcipher/web3j/integrity 등) 명세
  - `android/build.gradle` 이 로컬 maven 저장소(`repo/`)로 참조: `api 'com.dsrv.wallet:sdk:<version>'`
- 앱 `MainActivity` 는 **`FlutterFragmentActivity`** 여야 합니다 (백업/복원의 생체인증·Passkey UI).
  ```kotlin
  class MainActivity : FlutterFragmentActivity()
  ```

### iOS
- 플러그인이 `Frameworks/` 에 두 xcframework(바이너리)를 벤더합니다 (별도 빌드 불필요):
  - `dsrv_wallet_sdk_ios.xcframework` — SDK 본체
  - `Mpe.xcframework` — MPC 엔진
  - podspec 의 `vendored_frameworks` 가 이를 링크합니다.
- 배포 타깃 iOS 14+ (Passkey 백업 Tier A 는 iOS 18+ 에서 자동 활성, 미만은 Tier B 로 폴백). Passkey 사용 시 Associated Domains 설정 필요.

## API

native SDK 와 1:1. 모든 메서드는 `WalletResult<T>` 를 반환합니다.

```dart
// 초기화 (AuthHandler 는 native challenge 요청 시 역방향 호출됨)
await DSRVWallet.initialize(
  sdkId: 'your-sdk-id',
  userCredential: UserCredential(type: CredentialType.userId, value: uuid),
  authHandler: myAuthHandler,
  baseUrl: 'https://your-dsrv-api', // nullable
);

await DSRVWallet.createAccount(label: 'default');
await DSRVWallet.getAccountList();
await DSRVWallet.getChainList();
final key = (await DSRVWallet.create(chainType: 'EVM')).getOrThrow(); // {publicKey, address}

// 원샷 — build → MPC sign → broadcast 가 SDK 내부에서 한 번에 처리
await DSRVWallet.transfer(
  address: key.address, chainId: '11155111',
  asset: const TransferAsset.native(),       // 또는 TransferAsset.erc20('0x...')
  recipient: '0x...', amount: '1000000000000000', // wei, 10진 문자열
);

// 단계별 — caller 가 build/sign/broadcast 사이에 자체 로직(confirm UI 등)을 끼울 때
final build = (await DSRVWallet.buildTx(
  address: key.address, chainId: '11155111',
  asset: const TransferAsset.native(),
  recipient: '0x...', amount: '1000000000000000',
)).getOrThrow();
await DSRVWallet.sign(
  address: key.address,
  hashedMessage: build.messageHash,
  signId: build.signId,      // buildTx 응답의 signId 를 그대로
  messageType: build.type,
);
final broadcast = (await DSRVWallet.broadcastTx(
  address: key.address,
  txId: build.txId,          // buildTx 응답의 txId 를 그대로
)).getOrThrow();

await DSRVWallet.delegate(address: key.address);  // List<ChainTxResult>
await DSRVWallet.revoke(address: key.address);
// amount: 'MAX' = unbounded permit2 권한, '0' = 권한 해제. SDK 가 toUpperCase() 로 정규화.
await DSRVWallet.approve(address: key.address, amount: 'MAX'); // → List<ChainTxResult>

// 특정 address 의 chain 별 위임 (EIP-7702) + token 별 approve (Permit2) 상태 단건 조회.
await DSRVWallet.getSetupStatus(
  accountId: '<account-id>',
  addressId: '<address-id>',
); // → List<ChainSetupStatus> (each has delegated, approvals: List<TokenApproval>)

// backup() — 디바이스의 모든 wallet share 를 cloud 에 sync. address 별 결과 리스트 반환.
// 호출할 때마다 이미 백업된 wallet 도 재업로드 (의도된 동작, 'sync everything now' 의미).
// 로컬 세대 < cloud 세대인 stale wallet 은 덮어쓰지 않고 success=false(사유 포함)로 skip.
// 디바이스에 wallet 이 없으면 NoKeyShareToBackup (4204) 으로 실패 — createAddress()/restore() 먼저 안내.
final backedUp = (await DSRVWallet.backup()).getOrThrow(); // List<BackupResult> (iCloud / Google Drive)
// restore() — backup 의 대칭. 가져올 wallet 이 0개면 NoKeyShareToRestore (4205) 로 실패.
// message 로 sub-case 구분: "No backup found in cloud." / "All wallets are already restored on this device."
final restored = (await DSRVWallet.restore()).getOrThrow(); // List<RestoreResult>

// 사용자 전환 — 다음 initialize() 가 다른 userCredential 로 새로 인증되게 함 (로컬 DB 유지)
await DSRVWallet.reset();
```

### AuthHandler 구현

```dart
class MyAuthHandler implements AuthHandler {
  @override
  Future<ChallengeResult> requestChallenge(ChallengeRequest request) async {
    try {
      final challenge = await myBackend.requestChallenge(request); // 고객사 백엔드
      return ChallengeResult.success(challenge);
    } catch (e) {
      return ChallengeResult.failure(e.toString());
    }
  }
}
```

## 모델 / 에러

- 모델: `KeyCreateResult`, `BroadcastResult`, `ChainTxResult`, `TxBuildResult`, `SignResult`, `BackupResult`, `RestoreResult`, `AccountResult`, `AccountInfo`, `AddressInfo` (`hasLocalKeyShare` 포함), `ChainSetupStatus`, `TokenApproval`, `ChainInfo`, `TransferAsset`
- `ChainTxResult` — bulk operation 의 chain 별 결과 `(chainId, outcome, txHash?, errorMessage?, status?)`. `outcome` 값:
  - `NEW` (delegate) / `BUILT` (approve) — 신규 빌드 + sign + submit **접수** 성공. `txHash` 는 GS_OFF 값 / **GS_ON(bundler) null** (batchTxId 로 추적), `status` 채워짐
  - `RESUMED` (delegate) — 보관된 SIGNED 재사용 → 재 broadcast 접수 성공. `txHash` GS_OFF 값 / **GS_ON null**, `status` 채워짐
  - `ALREADY_DELEGATED` / `SKIPPED` — 처리 불필요 (submit 없음), `txHash`/`status` null
  - `FAILED` — 실패, `errorMessage` non-null, `txHash`/`status` null
- `status` (broadcast 직후 서버 상태, 예 `BROADCAST`/`BATCHED`/`MINED_FAILED`) 는 SDK 가 해석하지 않고 원본을 그대로 전달 — 온체인 체결 성공/실패 판단은 앱 몫.
- `isSuccess` getter 는 `outcome != 'FAILED'` 이므로 `ALREADY_DELEGATED` / `SKIPPED` 도 success 로 인정. **단 이는 broadcast 접수 성공까지만 의미하며 온체인 체결 성공이 아님** (`status`/indexer 로 판단). 일부 chain 만 실패해도 `WalletResult.success` 로 반환되므로 caller 가 각 entry 의 outcome 으로 분기해야 함.
- 결과: `WalletResult<T>` (`getOrThrow`/`getOrNull`/`fold`/`onSuccess`/`onFailure`)
- 에러: `WalletError(code, message)` — 코드 체계는 native 와 동일 (1001 notInitialized, 4201 backupFailed, 4301 delegationFailed, …)

## 주의

- 이 플러그인은 native 코드를 **바이너리로** 동봉합니다 (Android=난독화 AAR, iOS=xcframework). 새 SDK 버전을 받으면 해당 바이너리(`android/repo/`, `ios/Frameworks/`)만 교체하면 됩니다.
- 백업/복원은 OS 클라우드(iCloud/Google Drive) 기반이며 passphrase 방식이 아닙니다.

## 문의

기술 지원이 필요하시면 DSRV 개발팀에 문의해 주세요.
