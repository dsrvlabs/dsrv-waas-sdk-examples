# DSRV Wallet SDK Android Example

DSRV Wallet SDK를 사용하는 샘플 Android 애플리케이션입니다.

## 요구 사항

- Android Studio Ladybug | 2024.2.1 이상
- JDK 11 이상
- Android SDK API 26 이상 (Android 8.0)
- Gradle 8.13

---

## ⚠️ 환경 설정 (필수 — 실행 전 반드시 완료)

> 아래 설정 없이 빌드하거나 실행하면 SDK 초기화에 실패합니다.

`dsrv-wallet-sdk-android-example/gradle.properties` 파일에 아래 값들을 실제 값으로 채워주세요.

```properties
# 고객사 백엔드 서버 URL (AuthHandler가 호출할 엔드포인트 베이스 URL)
CUSTOMER_BACKEND_URL=https://your-backend.com

# DSRV API 베이스 URL (SDK 내부 통신용 — host + port 만, path prefix 는 SDK 가 자동 부착)
DSRV_API_BASE_URL=https://api.dsrv.com

# DSRV에서 발급받은 SDK ID
SDK_ID=your-sdk-id
```

| 키 | 설명 |
|----|------|
| `CUSTOMER_BACKEND_URL` | AuthHandler(`/sdk/registration`)가 호출할 고객사 백엔드 |
| `DSRV_API_BASE_URL` | DSRV SDK 내부 API 통신 주소 |
| `SDK_ID` | DSRV에서 발급한 SDK ID |

> **참고**: `gradle.properties`에 값이 없으면 `build.gradle.kts`에 정의된 기본값이 사용됩니다.

---

## 프로젝트 구조

```
dsrv-wallet-sdk-android-example/
├── app/
│   ├── libs/
│   │   └── sdk-release.aar          # DSRV Wallet SDK (바이너리)
│   └── src/main/java/com/dsrv/wallet/example/
│       ├── MainActivity.kt
│       └── wallet/
│           ├── model/
│           │   ├── Wallet.kt                # ViewModel (SDK 연동 핵심)
│           │   ├── WalletUiState.kt         # UI 상태
│           │   ├── WalletHandlers.kt        # AuthHandler 구현 (MyAuthHandler)
│           │   ├── TransferRepository.kt    # customer-backend /sdk/transfer/* 호출
│           │   ├── PaymentRepository.kt     # customer-backend /payments 호출
│           │   ├── Payment.kt               # Payment DTO
│           │   ├── Amount.kt                # human ↔ base units 변환
│           │   └── BalanceClient.kt         # RPC 잔액 조회
│           ├── config/
│           │   └── TokenConfig.kt           # chain 별 USDC 매핑
│           ├── component/
│           │   ├── SdkSection.kt            # initialize 호출 UI
│           │   ├── AccountSection.kt        # createAccount / getAccountList UI
│           │   ├── ChainSection.kt          # getChainList + chain 선택 UI
│           │   ├── TransferSection.kt       # 전송 UI (build → sign → broadcast)
│           │   ├── PaymentSection.kt        # Topup 결제 UI (POST /payments)
│           │   ├── DelegateSection.kt       # EIP-7702 delegate / revoke UI
│           │   ├── ApproveSection.kt        # 토큰 approve UI
│           │   ├── BackupSection.kt         # backup UI
│           │   ├── RestoreSection.kt        # restore UI
│           │   ├── LogSection.kt            # 실시간 로그
│           │   ├── QRScannerView.kt         # QR 스캔 (ML Kit)
│           │   ├── QRCodeView.kt            # QR 표시
│           │   └── CopyableText.kt          # 공통 복사 컴포넌트
│           └── screen/
│               ├── RootScreen.kt            # 루트 (Login | WalletList | WalletDetail | Feature 라우팅)
│               └── WalletScreen.kt          # 메뉴 기반 다단계 화면
```

> SDK 는 `app/libs/sdk-release.aar` (바이너리) 로 참조합니다. `app/build.gradle.kts` 의 `implementation(files("libs/sdk-release.aar"))` 참고.

---

## 샘플 앱 실행 방법

### Android Studio에서 실행

1. Android Studio에서 `dsrv-wallet-sdk-android-example` 프로젝트를 엽니다
2. 에뮬레이터 또는 실제 디바이스를 연결합니다
3. Run 버튼을 클릭합니다

### 터미널에서 설치

```bash
# 연결된 디바이스 확인
adb devices

# Debug APK 빌드 및 설치
./gradlew :app:assembleDebug
adb -s <DEVICE_ID> install -r app/build/outputs/apk/debug/app-debug.apk
```

---

## 🔐 SDK 연동 가이드

### 연동 흐름

```
┌─────────────┐   ┌──────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ 1.initialize│─▶│2.createAccount│─▶│  3. create  │─▶│  4. transfer │─▶│  5. refresh │
└─────────────┘   └──────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
```

- `createAccount` 는 서버 측 idempotent — 같은 label 재호출 시 기존 accountId 반환
- `create()` 는 로컬 `tb_account` 에 1개만 있으면 accountId 자동 선택

---

### 1️⃣ SDK 초기화

SDK를 사용하기 전에 반드시 초기화해야 합니다.

#### AuthHandler 구현

고객사 백엔드와 challenge 교환을 담당하는 핸들러를 구현합니다.

```kotlin
// WalletHandlers.kt
import com.dsrv.wallet.sdk.AuthHandler
import com.dsrv.wallet.sdk.ChallengeRequest
import com.dsrv.wallet.sdk.ChallengeResult
import org.json.JSONObject

class MyAuthHandler(
    private val backendUrl: String
) : AuthHandler {
    override suspend fun requestChallenge(request: ChallengeRequest): ChallengeResult {
        val jsonBody = JSONObject().apply {
            put("sdkId", request.sdkId)
            put("appId", request.appId)
            put("userCredential", JSONObject().apply {
                put("type", request.userCredential.type.name)
                put("value", request.userCredential.value)
                put("provider", request.userCredential.provider)
            })
            put("signingHash", request.signingHash)
            put("deviceInfo", JSONObject().apply {
                put("platform", request.deviceInfo.platform)
                put("publicKey", request.deviceInfo.publicKey)
                put("model", request.deviceInfo.model)
                put("osVersion", request.deviceInfo.osVersion)
                put("isVirtual", request.deviceInfo.isVirtual)
            })
        }.toString()

        return try {
            val response = post("$backendUrl/sdk/registration", jsonBody)
            val challenge = JSONObject(response).optJSONObject("data")?.optString("challenge")
            if (!challenge.isNullOrEmpty()) ChallengeResult.Success(challenge)
            else ChallengeResult.Failure("Missing challenge")
        } catch (e: Exception) {
            ChallengeResult.Failure(e.message ?: "Network error")
        }
    }
}
```

#### SDK 초기화 호출

```kotlin
// Wallet.kt (ViewModel)
import com.dsrv.wallet.sdk.DSRVWallet
import com.dsrv.wallet.sdk.CredentialType
import com.dsrv.wallet.sdk.UserCredential

class Wallet(application: Application) : AndroidViewModel(application) {

    var uiState by mutableStateOf(WalletUiState())
        private set
    var publicKey by mutableStateOf("")

    private fun initializeSdk() {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val uuid = getOrCreateUserId()

                val userCredential = UserCredential(
                    type = CredentialType.USER_ID,
                    value = uuid,
                    provider = ""
                )

                val result = DSRVWallet.initialize(
                    context = getApplication<Application>().applicationContext,
                    sdkId = BuildConfig.SDK_ID,
                    userCredential = userCredential,
                    authHandler = MyAuthHandler(BuildConfig.CUSTOMER_BACKEND_URL),
                    baseUrl = BuildConfig.DSRV_API_BASE_URL
                )

                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(sdkInitialized = result.isSuccess)
                }
            } catch (t: Throwable) {
                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(sdkInitError = t.message)
                }
            }
        }
    }
}
```

---

### 2️⃣ Account 및 지갑 생성

SDK 초기화 후 먼저 account 를 생성하고, 해당 account 에 MPC 지갑을 생성합니다.

```kotlin
fun createWallet() {
    viewModelScope.launch(Dispatchers.IO) {
        // 1. Account 생성 (idempotent — 같은 label 재호출 시 기존 반환)
        val accountResult = DSRVWallet.createAccount(label = "default")
        if (accountResult.isFailure) return@launch

        // 2. 해당 account 에 MPC 지갑 생성 (tb_account 에 1개뿐이면 accountId 생략 가능)
        // chainType 은 getChainList() 의 ChainInfo.chainType 을 그대로 전달 (예: "EVM")
        val result = DSRVWallet.create(chainType = "EVM")

        withContext(Dispatchers.Main) {
            if (result.isSuccess) {
                val created = result.getOrNull()!!

                // publicKey: 0x04-prefixed uncompressed (132자)
                publicKey = created.publicKey

                // secondaryKeyData는 반드시 앱에서 보관 (백업용)
                prefs.edit()
                    .putString(KEY_SECONDARY_KEY_DATA, created.secondaryKeyData)
                    .apply()
            } else {
                uiState = uiState.copy(createError = result.errorOrNull()?.message)
            }
        }
    }
}
```

> ⚠️ **`secondaryKeyData`는 반드시 앱이 안전하게 보관**해야 합니다. 이 값은 `refresh()` 호출에 필요하며, 분실 시 키 복구가 어려워집니다.

---

### 3️⃣ 트랜잭션 전송 (transfer)

example 의 `Wallet.transfer()` 는 build / broadcast 를 customer-backend 의
`/sdk/transfer/build-hash` 와 `/sdk/transfer/broadcast` endpoint 로 위임하고,
MPC sign 만 디바이스에서 `DSRVWallet.sign()` 으로 직접 수행합니다 (3단계 흐름).

SDK 의 원샷 `DSRVWallet.transfer()` 도 그대로 노출되므로 customer-backend 경유가 필요 없는
경우 한 줄로 부를 수 있습니다.

```kotlin
import com.dsrv.wallet.sdk.TransferAsset

// 원샷 — SDK 가 WaaS 와 직접 통신 (build → MPC sign → broadcast)
suspend fun sendNative(recipient: String, amountWei: String) {
    val result = DSRVWallet.transfer(
        address = walletAddress,
        chainId = "11155111",   // Sepolia
        asset = TransferAsset.Native,
        recipient = recipient,
        amount = amountWei      // wei (정수 문자열)
    ).getOrThrow()

    Log.d("Wallet", "Tx hash: ${result.txHash}")
}

// ERC-20 토큰 전송
suspend fun sendErc20(tokenAddress: String, recipient: String, amount: String) {
    val result = DSRVWallet.transfer(
        address = walletAddress,
        chainId = "11155111",
        asset = TransferAsset.Erc20(tokenAddress),
        recipient = recipient,
        amount = amount         // wei (정수 문자열)
    ).getOrThrow()

    Log.d("Wallet", "Tx hash: ${result.txHash}")
}
```

> 단계별 제어가 필요하면 `buildTx` → `sign` → `broadcastTx` 를 직접 부를 수도 있습니다.
> `buildTx` 응답의 `signId` 를 `sign(signId:)` 에, `buildTx` 응답의 `txId` 를 `broadcastTx(txId:)` 에 그대로 넣으면 됩니다.

---

### 4️⃣ EIP-7702 위임 / 철회 / 토큰 approve

스마트 어카운트 위임 후 결제 토큰을 한 번에 approve 합니다. 위임 해제는 `revoke()`.

```kotlin
suspend fun setupPayments() {
    // 1. 지원 chain 에 위임 일괄 처리 (이미 위임된 chain 은 skip)
    val delegated = DSRVWallet.delegate(publicKey = publicKey).getOrThrow()
    delegated.forEach { Log.d("Wallet", "delegate tx: ${it.txHash}") }

    // 2. Permit2 패턴으로 결제 토큰들 multicall approve (단일 tx)
    val approveTx = DSRVWallet.approve(
        publicKey = publicKey,
        chainId = "11155111",
        tokenAddresses = listOf("0xUSDC...", "0xUSDT...")
    ).getOrThrow()
    Log.d("Wallet", "approve tx: ${approveTx.txHash}")
}

suspend fun teardownPayments() {
    // 위임 철회 (address=0x0 으로 재위임)
    val revoked = DSRVWallet.revoke(publicKey = publicKey).getOrThrow()
    revoked.forEach { Log.d("Wallet", "revoke tx: ${it.txHash}") }
}
```

---

### 5️⃣ 키 갱신 (refresh)

주기적으로 또는 정책에 따라 MPC 키 share를 갱신합니다. `publicKey`는 바뀌지 않습니다.

```kotlin
fun refresh() {
    val secondaryKeyData = prefs.getString(KEY_SECONDARY_KEY_DATA, null) ?: return

    viewModelScope.launch(Dispatchers.IO) {
        val result = DSRVWallet.refresh(publicKey, secondaryKeyData)

        if (result.isSuccess) {
            val refreshed = result.getOrNull()!!
            // 새 secondaryKeyData로 덮어쓰기 필수
            prefs.edit()
                .putString(KEY_SECONDARY_KEY_DATA, refreshed.secondaryKeyData)
                .apply()
        }
    }
}
```

---

## 📋 SDK API 요약

| API | 설명 | 반환값 |
|-----|------|--------|
| `DSRVWallet.initialize(...)` | SDK 초기화 | `WalletResult<Unit>` |
| `DSRVWallet.createAccount(label)` | Account 생성 (idempotent) | `WalletResult<AccountResult>` |
| `DSRVWallet.getAccountList()` | 서버 account 목록 조회 | `WalletResult<List<AccountInfo>>` |
| `DSRVWallet.getChainList()` | 지원 체인 목록 조회 | `WalletResult<List<ChainInfo>>` |
| `DSRVWallet.create(accountId?, chainType, label?)` | MPC 지갑 생성 + WaaS 등록 | `WalletResult<KeyCreateResult>` |
| `DSRVWallet.transfer(address, chainId, asset, recipient, amount: String)` | 전송 원샷 (build hash → MPC sign → broadcast) | `WalletResult<TxHashResult>` |
| `DSRVWallet.buildTx(...)` | 단계별 전송 1 — build hash | `WalletResult<TxBuildResult>` |
| `DSRVWallet.sign(address, hashedMessage, signId, messageType)` | 단계별 전송 2 — MPC 서명 | `WalletResult<SignResult>` |
| `DSRVWallet.broadcastTx(address, txId)` | 단계별 전송 3 — broadcast | `WalletResult<TxHashResult>` |
| `DSRVWallet.delegate(address)` | EIP-7702 위임 (chain 일괄 처리) | `WalletResult<List<TxHashResult>>` |
| `DSRVWallet.revoke(address)` | EIP-7702 위임 철회 (chain 일괄 처리) | `WalletResult<List<TxHashResult>>` |
| `DSRVWallet.approve(address, chainId, tokenAddresses)` | 결제 토큰 multicall approve | `WalletResult<TxHashResult>` |
| `DSRVWallet.backup(activity)` | PENDING share3 를 Block Store 에 cloud sync | `WalletResult<Unit>` |
| `DSRVWallet.restore(activity)` | cloud sync 된 share3 로 지갑 복구 | `WalletResult<List<RestoredKey>>` |
| `DSRVWallet.dumpBlockStoreForDebug()` | (디버그) Block Store 덤프 | `String` |
| `DSRVWallet.clearBackupForDebug()` | (디버그) 모든 tier 백업 삭제 | `Unit` |
| `DSRVWallet.reset()` | 사용자 전환 — 다음 `initialize()` 가 다른 `UserCredential` 로 진행되게 함 (로컬 DB 유지) | `Unit` |

---

## 🗂️ UI 상태 관리

Jetpack Compose와 함께 사용하는 상태 관리 패턴입니다.

```kotlin
// WalletUiState.kt
data class WalletUiState(
    // SDK 상태
    val sdkInitialized: Boolean = false,
    val sdkInitializing: Boolean = true,
    val sdkInitError: String? = null,

    // 지갑 생성 상태
    val createLoading: Boolean = false,
    val createError: String? = null,

    // 전송 상태
    val transferLoading: Boolean = false,
    val transferError: String? = null,
    val lastTxHash: String? = null,

    // 갱신 상태
    val refreshLoading: Boolean = false,
    val refreshResult: String? = null,
    val refreshError: String? = null,

    // 로그
    val logs: List<String> = emptyList()
)
```

> **Note**: `DSRVWallet` 객체의 내부 상태는 Compose에서 자동 recomposition되지 않으므로, ViewModel에서 `mutableStateOf`로 UI 상태를 별도 관리하세요.

---

## ✅ 연동 체크리스트

- [ ] `gradle.properties`에 환경변수 설정 (`CUSTOMER_BACKEND_URL`, `DSRV_API_BASE_URL`, `SDK_ID`)
- [ ] `build.gradle`에 SDK 의존성 추가
- [ ] `AuthHandler` 구현 (고객사 백엔드 `/sdk/registration` 연동)
- [ ] ViewModel에서 `DSRVWallet.initialize()` 호출
- [ ] Account 생성: `DSRVWallet.createAccount(label)` (최초 1회, idempotent 라 재호출 가능)
- [ ] 지갑 생성: `DSRVWallet.create(chainType = "EVM")` — `getChainList()` 의 `ChainInfo.chainType` 사용
- [ ] `secondaryKeyData` 안전 보관 (SharedPreferences/Keystore 등)
- [ ] (선택) EIP-7702 위임: `DSRVWallet.delegate(publicKey)` — 결제 흐름 사용 전 1회 필요
- [ ] (선택) 결제 토큰 approve: `DSRVWallet.approve(publicKey, chainId, tokenAddresses)`
- [ ] 트랜잭션 전송: `DSRVWallet.transfer(publicKey, chainId, asset, recipient, amount)`
- [ ] UI 상태 관리 (Compose State 또는 LiveData)

---

## SDK 업데이트 방법

이 예제 앱은 SDK 를 **AAR 바이너리**(`app/libs/sdk-release.aar`)로 참조합니다. 새 버전으로 교체하려면 새 `sdk-release.aar` 를 `app/libs/` 에 덮어쓴 뒤 앱을 다시 빌드하세요.

```bash
./gradlew clean :app:assembleDebug
```

---

## 문의

기술 지원이 필요하시면 DSRV 개발팀에 문의해 주세요.
