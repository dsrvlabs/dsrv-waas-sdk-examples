package com.dsrv.wallet.example.wallet.model

import com.dsrv.wallet.sdk.AccountInfo
import com.dsrv.wallet.sdk.ChainSetupStatus
import com.dsrv.wallet.sdk.ChainInfo
import com.dsrv.wallet.sdk.ChainTxResult

data class WalletUiState(
    val sdkInitialized: Boolean = false,
    val sdkInitializing: Boolean = false,
    val sdkInitError: String? = null,
    // Account
    val createAccountLoading: Boolean = false,
    val createAccountError: String? = null,
    val accountsLoading: Boolean = false,
    val accountsError: String? = null,
    val accounts: List<AccountInfo> = emptyList(),
    val selectedAccountId: String? = null,
    // Chain
    val chainsLoading: Boolean = false,
    val chainsError: String? = null,
    val chains: List<ChainInfo> = emptyList(),
    val selectedChainId: String? = null,
    // Create
    val createLoading: Boolean = false,
    val createError: String? = null,
    // Transfer (원샷: buildTx + sign + broadcastTx)
    val transferLoading: Boolean = false,
    val transferError: String? = null,
    val lastTxHash: String? = null,
    // Backup
    val backupLoading: Boolean = false,
    val backupError: String? = null,
    val backupResult: String? = null,
    val blockStoreDump: String? = null,
    // Restore
    val restoreLoading: Boolean = false,
    val restoreError: String? = null,
    val restoreResult: String? = null,
    // Delegate / Revoke — chain 별 시도 결과 (성공/실패 모두 보존)
    val delegateLoading: Boolean = false,
    val delegateError: String? = null,
    val delegateResults: List<ChainTxResult> = emptyList(),
    val delegateAlreadyDone: Boolean = false,
    // Approve — chain 별 시도 결과 (multicall MAX, 지원 chain 일괄 처리)
    val approveLoading: Boolean = false,
    val approveError: String? = null,
    val approveResults: List<ChainTxResult> = emptyList(),
    // Setup status — chain 별 위임/승인 상태 조회 (read-only)
    val setupStatusLoading: Boolean = false,
    val setupStatusError: String? = null,
    val setupStatus: List<ChainSetupStatus> = emptyList(),
    // Payment (customer-backend POST /payments — TOPUP 흐름)
    val paymentLoading: Boolean = false,
    val paymentError: String? = null,
    val paymentResult: PaymentResponse? = null,
    // Transaction history (customer-backend GET /sdk/transactions)
    val historyLoading: Boolean = false,
    val historyError: String? = null,
    val historyItems: List<TransactionHistoryItem> = emptyList(),
    val historyTotal: Int = 0,
    val historyPage: Int = 0,
    // Asset list (WaaS getAccountAssets, 선택 체인 필터) — 전송 드롭다운/자산조회/결제 공용.
    // 선택·KRW 같은 화면별 상태는 각 컴포저블이 보관하고, 목록/로딩/에러만 여기서 관리한다.
    val assets: List<AssetRow> = emptyList(),
    val assetsLoading: Boolean = false,
    val assetsError: String? = null,
    // Logs
    val logs: List<String> = emptyList(),
)
