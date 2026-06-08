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
- 백업/Passkey/생체인증/MPC = native 그대로 동작 (iOS iCloud Keychain, Android Block Store)
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

await DSRVWallet.delegate(address: key.address);  // List<TxHashResult>
await DSRVWallet.revoke(address: key.address);
await DSRVWallet.approve(address: key.address, chainId: '11155111',
    tokenAddresses: ['0xUSDC...', '0xUSDT...']);

await DSRVWallet.backup();                         // iCloud / Block Store
final restored = (await DSRVWallet.restore()).getOrThrow(); // List<RestoredKey>

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

- 모델: `KeyCreateResult`, `TxHashResult`, `TxBuildResult`, `SignResult`, `RestoredKey`, `AccountResult`, `AccountInfo`, `AddressInfo`, `ChainInfo`, `TransferAsset`
- 결과: `WalletResult<T>` (`getOrThrow`/`getOrNull`/`fold`/`onSuccess`/`onFailure`)
- 에러: `WalletError(code, message)` — 코드 체계는 native 와 동일 (1001 notInitialized, 4201 backupFailed, 4301 delegationFailed, …)

## 주의

- 이 플러그인은 native 코드를 **바이너리로** 동봉합니다 (Android=난독화 AAR, iOS=xcframework). 새 SDK 버전을 받으면 해당 바이너리(`android/repo/`, `ios/Frameworks/`)만 교체하면 됩니다.
- 백업/복원은 OS 클라우드(iCloud/Block Store) 기반이며 passphrase 방식이 아닙니다.

## 문의

기술 지원이 필요하시면 DSRV 개발팀에 문의해 주세요.
