package com.dsrv.wallet.example.wallet.model

import android.app.Application
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.dsrv.wallet.example.BuildConfig
import com.dsrv.wallet.sdk.CredentialType
import com.dsrv.wallet.sdk.DSRVWallet
import com.dsrv.wallet.sdk.UserCredential
import com.dsrv.wallet.example.wallet.config.TokenConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class Wallet(application: Application) : AndroidViewModel(application) {
    companion object {
        private const val TAG = "Wallet"
        private const val PREFS_NAME = "dsrv_wallet_prefs"
        private const val KEY_USER_ID = "user_id"

        // demo 용 fallback — selectedChainId 가 없을 때만 사용 (Sepolia)
        private const val DEMO_CHAIN_ID_FALLBACK = "11155111"

        /**
         * userId 를 시드로 결정적 UUID (v3) 를 생성한다.
         * 같은 userId 는 항상 같은 UUID → SDK 세션을 사용자 단위로 잇는다.
         */
        fun userIdToUuid(userId: String): String {
            val seed = "dsrv-wallet-example:${userId.trim()}".toByteArray(Charsets.UTF_8)
            return UUID.nameUUIDFromBytes(seed).toString()
        }
    }

    private val prefs = application.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var uiState by mutableStateOf(WalletUiState())
        private set

    /** 선택된 지갑의 EVM address (0x-prefixed). SDK API 호출의 주 식별자. */
    var address by mutableStateOf("")
    /** 선택된 지갑의 publicKey (UI 표시 용도). */
    var publicKey by mutableStateOf("")

    val customerBackendUrl: String = BuildConfig.CUSTOMER_BACKEND_URL
    val sdkId: String = BuildConfig.SDK_ID
    val dsrvApiBaseUrl: String = BuildConfig.DSRV_API_BASE_URL

    /**
     * 사용자 입력 식별자. customer-backend `/sdk/registration` 의 `userCredential.value` 로 전달되는
     * [userUuid] 는 이 값을 시드로 결정적 생성됨 — 같은 userId 는 항상 같은 UUID 를 가짐.
     * 앱 최초 진입 시 빈 문자열로 초기화되어 LoginScreen 에서 입력받는다.
     */
    var userId: String by mutableStateOf(loadOrCreateUserId())
        private set

    /** [userId] 시드로 만들어진 결정적 UUID (Login 화면에 미리 보여주는 값). */
    val userUuid: String
        get() = if (userId.isBlank()) "" else userIdToUuid(userId)

    private fun loadOrCreateUserId(): String {
        return prefs.getString(KEY_USER_ID, "") ?: ""
    }

    /**
     * userId 를 변경한다 (사용자 전환).
     * 이미 SDK 초기화 상태라면 [DSRVWallet.reset] 으로 `initialized` 플래그를 풀어 다음
     * [initializeSdk] 가 새 [UserCredential] 로 진행되게 한다. 로컬 DB(`tb_tokens` 포함)는
     * 보존되며, 새 userId 는 자신의 token row 가 없어 자연스럽게 재인증 흐름을 탄다.
     */
    fun changeUserId(newUserId: String) {
        val trimmed = newUserId.trim()
        if (trimmed.isEmpty() || trimmed == userId) return

        // 다른 사용자 전환: SDK reset → 다음 initialize() 가 새 userCredential 로 진행되도록.
        if (uiState.sdkInitialized) {
            DSRVWallet.reset()
            publicKey = ""
            address = ""
            uiState = WalletUiState()
            addLog("⚙ SDK reset (userId 변경)")
        }

        userId = trimmed
        prefs.edit().putString(KEY_USER_ID, trimmed).apply()
        addLog("⚙ userId='$trimmed' → uuid=${userUuid.take(12)}…")
    }

    private fun addLog(message: String) {
        val timestamp = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
            .format(java.util.Date())
        val line = "[$timestamp] $message"
        Log.d(TAG, line)
        uiState = uiState.copy(logs = uiState.logs + line)
    }

    fun clearLogs() {
        uiState = uiState.copy(logs = emptyList())
    }

    private fun initializeSdk() {
        addLog("▶ initialize")
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val authHandler = MyAuthHandler(customerBackendUrl)
                val userCredential = UserCredential(
                    type = CredentialType.USER_ID,
                    value = userUuid,
                    provider = "",
                )
                addLog("  userUuid=${userUuid.take(8)}…, sdkId=$sdkId")
                addLog("  customer-backend=$customerBackendUrl")

                val result = DSRVWallet.initialize(
                    context = getApplication<Application>().applicationContext,
                    sdkId = sdkId,
                    userCredential = userCredential,
                    authHandler = authHandler,
                    baseUrl = dsrvApiBaseUrl
                )

                if (result.isSuccess) {
                    withContext(Dispatchers.Main) {
                        uiState = uiState.copy(
                            sdkInitialized = true,
                            sdkInitializing = false,
                            sdkInitError = null
                        )
                        addLog("✓ initialize OK")
                    }
                    // SDK 초기화 직후 지원체인 자동 조회 — 헤더에 기본 노출되도록.
                    // getChainList() 내부에서 selectedChainId 비어 있으면 첫 chain 자동 선택.
                    getChainList()
                } else {
                    throw Exception(result.errorOrNull()?.message ?: "SDK 초기화 실패")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "SDK init failed", t)
                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(
                        sdkInitialized = false,
                        sdkInitializing = false,
                        sdkInitError = t.message ?: "SDK 초기화 실패"
                    )
                    addLog("✗ initialize FAILED: ${t.message}")
                }
            }
        }
    }

    /** UI 코드 호환용 alias — 새 SDK 는 address 를 직접 제공하므로 그대로 노출. */
    val addressText: String get() = address

    fun retryInitialize() {
        if (uiState.sdkInitializing) return
        if (userId.isBlank()) {
            uiState = uiState.copy(sdkInitError = "userId 를 먼저 입력하세요")
            return
        }
        uiState = uiState.copy(sdkInitializing = true, sdkInitError = null)
        initializeSdk()
    }

    fun resetWallet() {
        if (uiState.sdkInitialized) DSRVWallet.reset()
        publicKey = ""
        address = ""
        prefs.edit().remove(KEY_USER_ID).apply()
        uiState = WalletUiState()
        userId = ""
        addLog("▶ SDK reset — userId cleared")
    }

    // ===== Account =====

    fun createAccount(labelInput: String = "") {
        if (!uiState.sdkInitialized) return
        val label = labelInput.takeIf { it.isNotBlank() } ?: "test-${System.currentTimeMillis()}"
        uiState = uiState.copy(createAccountLoading = true, createAccountError = null)
        addLog("▶ createAccount(label=$label)")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.createAccount(label)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(createAccountLoading = false)
                if (result.isSuccess) {
                    val r = result.getOrNull()!!
                    uiState = uiState.copy(selectedAccountId = r.accountId)
                    addLog("✓ createAccount accountId=${r.accountId}, label=${r.label}")
                    // 새 계정이 즉시 목록에 반영되도록 자동 갱신
                    getAccountList()
                } else {
                    val error = result.errorOrNull()
                    uiState = uiState.copy(createAccountError = error?.message)
                    addLog("✗ createAccount FAILED: ${error?.message}")
                }
            }
        }
    }

    fun getAccountList() {
        if (!uiState.sdkInitialized) return
        uiState = uiState.copy(accountsLoading = true, accountsError = null)
        addLog("▶ getAccountList")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.getAccountList()
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(accountsLoading = false)
                if (result.isSuccess) {
                    val list = result.getOrNull()!!
                    // 기존 선택값이 없거나 목록에 없으면 마지막 account 로 갱신
                    val selected = uiState.selectedAccountId
                        ?.takeIf { prev -> list.any { it.accountId == prev } }
                        ?: list.lastOrNull()?.accountId
                    uiState = uiState.copy(accounts = list, selectedAccountId = selected)
                    addLog("✓ getAccountList count=${list.size} (selected=${selected ?: "none"})")
                    list.forEach { addLog("  accountId=${it.accountId}, label=${it.label}, addresses=${it.addresses.size}") }
                } else {
                    val error = result.errorOrNull()
                    uiState = uiState.copy(accountsError = error?.message)
                    addLog("✗ getAccountList FAILED: ${error?.message}")
                }
            }
        }
    }

    // ===== Chain =====

    fun getChainList() {
        if (!uiState.sdkInitialized) return
        uiState = uiState.copy(chainsLoading = true, chainsError = null)
        addLog("▶ getChainList")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.getChainList()
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(chainsLoading = false)
                if (result.isSuccess) {
                    val list = result.getOrNull()!!
                    val selected = uiState.selectedChainId ?: list.firstOrNull()?.chainId
                    uiState = uiState.copy(chains = list, selectedChainId = selected)
                    addLog("✓ getChainList count=${list.size}")
                    list.forEach { addLog("  chainId=${it.chainId}, name=${it.name}, type=${it.chainType}/${it.networkType}") }
                } else {
                    val error = result.errorOrNull()
                    uiState = uiState.copy(chainsError = error?.message)
                    addLog("✗ getChainList FAILED: ${error?.message}")
                }
            }
        }
    }

    fun selectChain(chainId: String) {
        uiState = uiState.copy(selectedChainId = chainId)
        addLog("⚙ selected chainId=$chainId")
    }

    /**
     * 사용자가 계정 목록 중에서 명시적으로 선택할 때.
     *
     * 선택된 계정의 첫 번째 address 가 있으면 그 publicKey 로 지갑 자동 매핑.
     * 없으면 publicKey 는 비워둔 채로 (해당 계정에 신규 지갑 생성 가능 상태) 둔다.
     */
    fun selectAccount(accountId: String) {
        val acc = uiState.accounts.find { it.accountId == accountId } ?: return
        val first = acc.addresses.firstOrNull()
        // SDK 가 lowercase address 로 키를 저장하므로 selectXxx 도 일관되게 lowercase 로.
        address = first?.address?.lowercase() ?: ""
        publicKey = first?.publicKey ?: ""
        uiState = uiState.copy(selectedAccountId = accountId)
        addLog("⚙ account selected: ${acc.label} (${acc.accountId.take(8)}…), wallet=${address.takeIf { it.isNotEmpty() } ?: "(none)"}")
    }

    /** 같은 계정 안에 여러 address 가 있을 때 선택. */
    fun selectWallet(addr: String) {
        val normalized = addr.lowercase()
        val info = uiState.accounts
            .flatMap { it.addresses }
            .firstOrNull { it.address.equals(normalized, ignoreCase = true) }
        address = info?.address?.lowercase() ?: normalized
        publicKey = info?.publicKey ?: ""
        addLog("⚙ wallet selected: ${address.take(20)}…")
    }

    // ===== Create address =====

    fun createAddress(accountIdInput: String = "", labelInput: String = "") {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(createError = "SDK가 초기화되지 않았습니다")
            return
        }
        // 입력값 우선, 없으면 메모리에 보관된 selectedAccountId. accountId 는 SDK 필수.
        val accountId = accountIdInput.takeIf { it.isNotBlank() } ?: uiState.selectedAccountId
        if (accountId.isNullOrBlank()) {
            uiState = uiState.copy(createError = "accountId 가 필요합니다 (먼저 getAccountList / createAccount)")
            return
        }
        val label = labelInput.takeIf { it.isNotBlank() }

        // 선택된 chain 의 chainType 을 그대로 사용 (없으면 "EVM" fallback)
        val chainType = uiState.chains
            .firstOrNull { it.chainId == uiState.selectedChainId }
            ?.chainType
            ?: "EVM"

        uiState = uiState.copy(createLoading = true, createError = null)
        addLog("▶ createAddress(accountId=$accountId, chainType=$chainType, label=${label ?: "null"})")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.createAddress(accountId = accountId, chainType = chainType, label = label)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(createLoading = false)
                if (result.isSuccess) {
                    val created = result.getOrNull()!!
                    publicKey = created.publicKey
                    address = created.address
                    uiState = uiState.copy(createError = null)
                    addLog("✓ createAddress address=${created.address}, publicKey=${created.publicKey.take(20)}…")
                    // 새 지갑이 계정 카드의 지갑 목록에 즉시 반영되도록 자동 갱신
                    getAccountList()
                } else {
                    val error = result.errorOrNull()
                    uiState = uiState.copy(createError = error?.message ?: "지갑 생성 실패")
                    addLog("✗ create FAILED: ${error?.message}")
                }
            }
        }
    }


    private val transferRepository by lazy { TransferRepository(customerBackendUrl) }

    /**
     * 전송 — 헤더 선택 체인 + 선택 지갑 사용. amount 는 사람이 읽는 단위 ("0.001", "1.5").
     *
     * 흐름 (버튼 1회 = 3단계):
     *   1) customer-backend `POST /sdk/transfer/build-hash`  → WaaS 가 build, signId/messageHash/type 반환
     *   2) [DSRVWallet.sign] (디바이스 MPC sign — 디바이스 ↔ MPC 서버 직통, proxy 불가)
     *   3) customer-backend `POST /sdk/transfer/broadcast`    → WaaS 가 broadcast 후 txHash 반환
     *
     * build/broadcast 는 customer-backend 가 자체 server-key 로 WaaS 호출 — example 은 user token 미전송.
     *
     * @param tokenSymbol "ETH" (native) 또는 TokenConfig 에 정의된 ERC-20 심볼 (예: "USDC")
     */
    fun transfer(
        recipientInput: String,
        amountInput: String,
        tokenSymbol: String = "ETH",
    ) {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(transferError = "SDK가 초기화되지 않았습니다")
            return
        }
        val addr = address
        if (addr.isEmpty()) {
            uiState = uiState.copy(transferError = "address 가 필요합니다")
            return
        }
        val chainId = uiState.selectedChainId ?: DEMO_CHAIN_ID_FALLBACK
        if (recipientInput.isBlank()) {
            uiState = uiState.copy(transferError = "수신 주소를 입력하세요")
            return
        }
        val recipient = recipientInput

        // 토큰 종류에 따라 contractAddress + decimals + 기본값 결정
        val (contractAddress, decimals, defaultHuman) = if (tokenSymbol == "ETH") {
            Triple<String?, Int, String>(null, 18, "0.001")
        } else {
            val token = TokenConfig.getToken(chainId, tokenSymbol) ?: run {
                uiState = uiState.copy(transferError = "chainId=$chainId 에 정의된 $tokenSymbol 이 없습니다 (설정에서 추가)")
                return
            }
            Triple<String?, Int, String>(token.address, token.decimals, "1")
        }
        val humanAmount = amountInput.trim().ifEmpty { defaultHuman }
        val amount = runCatching { toBaseUnits(humanAmount, decimals) }
            .getOrElse {
                uiState = uiState.copy(transferError = "amount 형식 오류: ${it.message}")
                return
            }

        uiState = uiState.copy(transferLoading = true, transferError = null)
        addLog("▶ transfer($tokenSymbol, chainId=$chainId, to=${recipient.take(10)}…, amount=$humanAmount → $amount base)")

        viewModelScope.launch(Dispatchers.IO) {
            try {
                // ── 1) customer-backend build ─────────────────────────
                addLog("  [1/3] backend build-hash")
                val build = transferRepository.buildHash(
                    BuildTransferRequest(
                        fromAddress = addr,
                        toAddress = recipient,
                        amount = amount.toString(),
                        chainId = chainId,
                        contractAddress = contractAddress,
                    )
                )
                addLog("       type=${build.type}, txId=${build.txId.take(20)}…")

                // ── 2) SDK sign (디바이스 MPC) ─────────────────────────
                addLog("  [2/3] SDK MPC sign")
                val signResult = DSRVWallet.sign(
                    address = addr,
                    hashedMessage = build.messageHash,
                    signId = build.signId,
                    messageType = build.type,
                )
                if (signResult.isFailure) {
                    val msg = signResult.errorOrNull()?.message ?: "sign 실패"
                    withContext(Dispatchers.Main) {
                        uiState = uiState.copy(transferLoading = false, transferError = msg)
                        addLog("✗ transfer sign FAILED: $msg")
                    }
                    return@launch
                }
                addLog("       sign OK")

                // ── 3) customer-backend broadcast ─────────────────────
                addLog("  [3/3] backend broadcast")
                val broadcast = transferRepository.broadcast(
                    BroadcastTransferRequest(txId = build.txId)
                )

                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(transferLoading = false, lastTxHash = broadcast.txHash)
                    val hash = broadcast.txHash
                    if (hash != null) {
                        addLog("✓ transfer txHash=$hash (status=${broadcast.status})")
                    } else {
                        addLog("✓ transfer queued — status=${broadcast.status}, batchTxId=${broadcast.batchTxId} (bundler 경로, txHash 후속 polling)")
                    }
                }
            } catch (t: Throwable) {
                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(transferLoading = false, transferError = t.message ?: "전송 실패")
                    addLog("✗ transfer FAILED: ${t.message}")
                }
            }
        }
    }

    // ===== Transaction history (customer-backend GET /sdk/transactions) =====

    private val transactionHistoryRepository by lazy { TransactionHistoryRepository(customerBackendUrl) }

    /**
     * 거래 내역 조회 — 선택된 지갑 [address] 기준 (fromAddress 필터).
     *
     * customer-backend `GET /sdk/transactions` 호출 → WaaS
     * `GET /api/v1/embedded-wallets/ncw/transactions?searchBy=FROM_ADDRESS` 프록시.
     * build/broadcast 와 마찬가지로 customer-backend 가 자체 server-key 로 WaaS 호출.
     *
     * @param loadMore true 면 다음 페이지를 기존 목록 뒤에 append, false 면 1페이지부터 새로 조회
     */
    fun getTransactionHistory(loadMore: Boolean = false) {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(historyError = "SDK가 초기화되지 않았습니다")
            return
        }
        val addr = address
        if (addr.isEmpty()) {
            uiState = uiState.copy(historyError = "address 가 필요합니다")
            return
        }
        if (uiState.historyLoading) return
        val page = if (loadMore) uiState.historyPage + 1 else 1

        uiState = uiState.copy(historyLoading = true, historyError = null)
        addLog("▶ getTransactionHistory(address=${addr.take(10)}…, page=$page)")

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val response = transactionHistoryRepository.getTransactions(
                    address = addr,
                    page = page,
                )
                withContext(Dispatchers.Main) {
                    val items = if (loadMore) uiState.historyItems + response.items else response.items
                    uiState = uiState.copy(
                        historyLoading = false,
                        historyItems = items,
                        historyTotal = response.pagination.total,
                        historyPage = response.pagination.page,
                    )
                    addLog("✓ getTransactionHistory page=${response.pagination.page}, count=${response.items.size}, total=${response.pagination.total}")
                }
            } catch (t: Throwable) {
                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(historyLoading = false, historyError = t.message ?: "거래 내역 조회 실패")
                    addLog("✗ getTransactionHistory FAILED: ${t.message}")
                }
            }
        }
    }

    // ===== Backup =====

    fun backup(activity: FragmentActivity) {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(backupError = "SDK 가 초기화되지 않았습니다")
            return
        }

        uiState = uiState.copy(backupLoading = true, backupError = null, backupResult = null)
        addLog("▶ backup (BlockStore + Passkey)")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.backup(activity)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(backupLoading = false)
                if (result.isSuccess) {
                    uiState = uiState.copy(backupResult = "백업 완료")
                    addLog("✓ backup OK")
                } else {
                    val error = result.errorOrNull()
                    uiState = uiState.copy(backupError = error?.message ?: "백업 실패")
                    addLog("✗ backup FAILED: ${error?.message}")
                }
            }
        }
    }

    fun dumpBlockStore() {
        if (!uiState.sdkInitialized) return
        addLog("▶ dumpBlockStore()")
        viewModelScope.launch(Dispatchers.IO) {
            val dump = runCatching { DSRVWallet.dumpBlockStoreForDebug() }
                .getOrElse { "dump failed: ${it.message}" }
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(blockStoreDump = dump)
                addLog("✓ dumpBlockStore (${dump.length}B)")
            }
        }
    }

    fun clearBackup() {
        if (!uiState.sdkInitialized) return
        addLog("▶ clearBackupForDebug()")
        viewModelScope.launch(Dispatchers.IO) {
            runCatching { DSRVWallet.clearBackupForDebug() }
            val dump = runCatching { DSRVWallet.dumpBlockStoreForDebug() }
                .getOrElse { "dump failed: ${it.message}" }
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(blockStoreDump = dump)
                addLog("✓ backup 전체 삭제 완료")
            }
        }
    }

    // ===== Delegate =====

    fun delegate(addressInput: String = "") {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(delegateError = "SDK 가 초기화되지 않았습니다")
            return
        }
        val addr = addressInput.takeIf { it.isNotBlank() } ?: address
        if (addr.isEmpty()) {
            uiState = uiState.copy(delegateError = "address 가 필요합니다 (create 먼저 실행)")
            return
        }

        uiState = uiState.copy(
            delegateLoading = true,
            delegateError = null,
            delegateResults = emptyList(),
            delegateAlreadyDone = false,
        )
        addLog("▶ delegate(address=$addr)")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.delegate(addr)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(delegateLoading = false)
                if (result.isSuccess) {
                    val list = result.getOrNull()!!
                    val successes = list.count { it.isSuccess }
                    val failures = list.size - successes
                    uiState = uiState.copy(
                        delegateResults = list,
                        delegateAlreadyDone = list.isEmpty(),
                    )
                    if (list.isEmpty()) addLog("ⓘ delegate skip: 이미 위임됨")
                    else {
                        addLog("✓ delegate (success=$successes / failed=$failures of ${list.size})")
                        list.forEach {
                            if (!it.isSuccess) addLog("  ✗ ${it.chainId} [${it.outcome}]: ${it.errorMessage ?: "unknown"}")
                            else if (it.txHash != null) addLog("  ✓ ${it.chainId} [${it.outcome}]: ${it.txHash}")
                            else addLog("  ✓ ${it.chainId} [${it.outcome}]")  // ALREADY_DELEGATED / SKIPPED
                        }
                    }
                } else {
                    val msg = result.errorOrNull()?.message ?: "위임 실패"
                    if (msg.contains("ALREADY_REGISTERED")) {
                        uiState = uiState.copy(delegateAlreadyDone = true)
                        addLog("ⓘ delegate skip: 이미 위임됨 (ALREADY_REGISTERED)")
                    } else {
                        uiState = uiState.copy(delegateError = msg)
                        addLog("✗ delegate FAILED: $msg")
                    }
                }
            }
        }
    }

    // ===== Revoke =====

    fun revoke(addressInput: String = "") {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(delegateError = "SDK 가 초기화되지 않았습니다")
            return
        }
        val addr = addressInput.takeIf { it.isNotBlank() } ?: address
        if (addr.isEmpty()) {
            uiState = uiState.copy(delegateError = "address 가 필요합니다")
            return
        }

        uiState = uiState.copy(delegateLoading = true, delegateError = null)
        addLog("▶ revoke(address=$addr)")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.revoke(addr)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(delegateLoading = false)
                if (result.isSuccess) {
                    val list = result.getOrNull()!!
                    val successes = list.count { it.isSuccess }
                    val failures = list.size - successes
                    uiState = uiState.copy(
                        delegateResults = emptyList(),
                        delegateAlreadyDone = false,
                    )
                    if (list.isEmpty()) addLog("ⓘ revoke skip: 위임된 체인 없음")
                    else {
                        addLog("✓ revoke (success=$successes / failed=$failures of ${list.size})")
                        list.forEach {
                            if (!it.isSuccess) addLog("  ✗ ${it.chainId} [${it.outcome}]: ${it.errorMessage ?: "unknown"}")
                            else if (it.txHash != null) addLog("  ✓ ${it.chainId} [${it.outcome}]: ${it.txHash}")
                            else addLog("  ✓ ${it.chainId} [${it.outcome}]")  // ALREADY_DELEGATED / SKIPPED
                        }
                    }
                } else {
                    val msg = result.errorOrNull()?.message ?: "해제 실패"
                    uiState = uiState.copy(delegateError = msg)
                    addLog("✗ revoke FAILED: $msg")
                }
            }
        }
    }

    // ===== Approve =====

    /**
     * 결제 컨트랙트로의 토큰 approve(MAX) 셋업을 **지원 chain 전체**에 일괄 처리한다.
     * 대상 token 은 WaaS 의 `project_assets` 에 등록된 활성 ERC-20 으로 자동 결정 (client 입력 없음).
     * 위임이 사전에 설치되어 있어야 한다 ([delegate] 선행).
     */
    fun approve(addressInput: String = "") {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(approveError = "SDK 가 초기화되지 않았습니다")
            return
        }
        val addr = addressInput.takeIf { it.isNotBlank() } ?: address
        if (addr.isEmpty()) {
            uiState = uiState.copy(approveError = "address 가 필요합니다 (createAddress 먼저 실행)")
            return
        }

        uiState = uiState.copy(approveLoading = true, approveError = null, approveResults = emptyList())
        addLog("▶ approve(address=${addr.take(10)}…)")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.approve(address = addr)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(approveLoading = false)
                if (result.isSuccess) {
                    val list = result.getOrNull() ?: emptyList()
                    val successes = list.count { it.isSuccess }
                    val failures = list.size - successes
                    uiState = uiState.copy(approveResults = list)
                    addLog("✓ approve (success=$successes / failed=$failures of ${list.size})")
                    list.forEach {
                        if (!it.isSuccess) addLog("  ✗ ${it.chainId} [${it.outcome}]: ${it.errorMessage ?: "unknown"}")
                        else if (it.txHash != null) addLog("  ✓ ${it.chainId} [${it.outcome}]: ${it.txHash}")
                        else addLog("  ✓ ${it.chainId} [${it.outcome}]")
                    }
                } else {
                    val msg = result.errorOrNull()?.message ?: "Approve 실패"
                    uiState = uiState.copy(approveError = msg)
                    addLog("✗ approve FAILED: $msg")
                }
            }
        }
    }

    // ===== Payment (customer-backend POST /payments — TOPUP) =====

    private val paymentRepository by lazy { PaymentRepository(customerBackendUrl) }

    /**
     * customer-backend `POST /payments` 호출. 서버가 quote → paymentDigest 서명 → execute 를 통합 처리.
     *
     * 비어 있는 입력값은 합리적 default 로 채움:
     *   sourceUserId → [userUuid] (raw userId 를 시드로 만든 결정적 UUID — WaaS 가 topup
     *                  wallet 등록 시 external_user_ref 로 박는 값과 동일해야 매칭됨)
     *   chainId      → 선택된 chain (없으면 [DEMO_CHAIN_ID_FALLBACK])
     *   token        → 선택된 chain 의 USDC ([TokenConfig])
     *   from         → 현재 선택된 지갑 [address]
     *   paymentType  → 0
     */
    fun pay(
        sourceUserIdInput: String = "",
        chainIdInput: String = "",
        tokenInput: String = "",
        fromInput: String = "",
        toInput: String,
        amountInput: String,
        paymentTypeInput: String = "",
    ) {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(paymentError = "SDK 가 초기화되지 않았습니다")
            return
        }
        val from = fromInput.takeIf { it.isNotBlank() } ?: address
        if (from.isEmpty()) {
            uiState = uiState.copy(paymentError = "from 주소가 필요합니다 (create 먼저 실행)")
            return
        }
        if (toInput.isBlank()) {
            uiState = uiState.copy(paymentError = "to 주소를 입력하세요 (SETTLEMENT 지갑)")
            return
        }
        if (amountInput.isBlank()) {
            uiState = uiState.copy(paymentError = "amount (예: 1.5) 를 입력하세요")
            return
        }
        val sourceUserId = sourceUserIdInput.ifBlank { userId }
        if (sourceUserId.isBlank()) {
            uiState = uiState.copy(paymentError = "sourceUserId 가 필요합니다 (userId 입력 후 init)")
            return
        }
        val chainIdStr = chainIdInput.takeIf { it.isNotBlank() }
            ?: uiState.selectedChainId
            ?: DEMO_CHAIN_ID_FALLBACK
        val chainId = chainIdStr.toIntOrNull() ?: run {
            uiState = uiState.copy(paymentError = "chainId 정수 변환 실패: $chainIdStr")
            return
        }
        val token = tokenInput.takeIf { it.isNotBlank() }
            ?: TokenConfig.getToken(chainIdStr, "USDC")?.address
            ?: run {
                uiState = uiState.copy(paymentError = "chainId=$chainIdStr 의 USDC 주소가 정의되지 않았습니다. token 직접 입력")
                return
            }
        val paymentType = paymentTypeInput.takeIf { it.isNotBlank() }?.toIntOrNull() ?: 0

        val request = PaymentRequest(
            sourceUserId = sourceUserId,
            chainId = chainId,
            token = token,
            from = from,
            to = toInput.trim(),
            amount = amountInput.trim(),
            paymentType = paymentType,
        )

        uiState = uiState.copy(paymentLoading = true, paymentError = null, paymentResult = null)
        addLog("▶ pay(chainId=$chainId, from=${from.take(10)}…, to=${request.to.take(10)}…, amount=${request.amount})")

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val response = paymentRepository.pay(request)
                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(paymentLoading = false, paymentResult = response)
                    addLog("✓ pay status=${response.status}, txHash=${response.txHash}, paymentUuid=${response.paymentUuid}")
                }
            } catch (t: Throwable) {
                withContext(Dispatchers.Main) {
                    uiState = uiState.copy(paymentLoading = false, paymentError = t.message ?: "결제 실패")
                    addLog("✗ pay FAILED: ${t.message}")
                }
            }
        }
    }

    // ===== Restore (BlockStore + Passkey) =====

    fun restore(activity: FragmentActivity) {
        if (!uiState.sdkInitialized) {
            uiState = uiState.copy(restoreError = "SDK 가 초기화되지 않았습니다")
            return
        }

        uiState = uiState.copy(restoreLoading = true, restoreError = null, restoreResult = null)
        addLog("▶ restore (BlockStore + Passkey)")

        viewModelScope.launch(Dispatchers.IO) {
            val result = DSRVWallet.restore(activity)
            withContext(Dispatchers.Main) {
                uiState = uiState.copy(restoreLoading = false)
                if (result.isSuccess) {
                    val list = result.getOrNull()!!
                    val ok = list.count { it.success }
                    val fail = list.count { !it.success }
                    uiState = uiState.copy(restoreResult = "복원 완료 (성공 $ok · 실패 $fail)")
                    addLog("✓ restore OK — 성공 $ok / 실패 $fail")
                    list.filter { !it.success }.forEach {
                        addLog("  ✗ ${it.address.take(10)}…: ${it.error}")
                    }
                    // 복원 후 계정 목록 새로고침
                    getAccountList()
                } else {
                    val error = result.errorOrNull()
                    uiState = uiState.copy(restoreError = error?.message ?: "복원 실패")
                    addLog("✗ restore FAILED: ${error?.message}")
                }
            }
        }
    }

}
