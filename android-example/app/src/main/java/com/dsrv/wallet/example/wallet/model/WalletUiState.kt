package com.dsrv.wallet.example.wallet.model

import com.dsrv.wallet.sdk.AccountInfo
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
    // Logs
    val logs: List<String> = emptyList(),
)
