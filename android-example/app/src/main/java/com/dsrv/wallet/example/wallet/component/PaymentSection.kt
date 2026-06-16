package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet
import kotlinx.coroutines.launch

/**
 * customer-backend `POST /payments` 호출 — Topup 결제 흐름.
 *
 * 결제(topup)는 stablecoin Payments 레일이라 **USDC 전용**입니다 (native·기타 토큰은 upstream
 * `CreateQuoteRequest` 가 ERC-20 컨트랙트 주소를 강제 — 미지원). 따라서 토큰은 USDC 로 고정
 * (체인별 컨트랙트 주소 하드코딩), 잔액은 공용 [Wallet.uiState] 자산목록에서 USDC 를 찾아 표시,
 * KRW 는 price-hub. chainId/token(USDC 주소)은 여기서, paymentType=0/sourceUserId/from 은 [Wallet.pay] 가 채움.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val lifecycleOwner = LocalContext.current as LifecycleOwner
    val scope = rememberCoroutineScope()
    val address = wallet.addressText

    val chainId = state.selectedChainId.orEmpty()
    val chain = state.chains.firstOrNull { it.chainId == chainId }
    // 결제 토큰 = 선택 체인의 USDC (하드코딩). stablecoin 측이 USDC 만 허용.
    val usdcAddr = usdcAddress(chainId)

    // 자산 목록/로딩/에러는 공용 상태(uiState)에서 관찰. KRW 만 이 컴포저블이 보관.
    val loading = state.assetsLoading
    val loadError = state.assetsError
    // 보유 USDC (공용 자산목록에서 컨트랙트 주소로 매칭). 미보유면 null → 잔액 0 표시.
    val usdc = usdcAddr?.let { addr ->
        state.assets.firstOrNull { it.contractAddress?.equals(addr, ignoreCase = true) == true }
    }
    var krwText by remember { mutableStateOf<String?>(null) }
    var krwLoading by remember { mutableStateOf(false) }
    // 빠른 체인/계정 전환·연속 새로고침 시 이전 응답이 현재 KRW 를 덮어쓰지 못하게 하는 가드 (iOS/Flutter 동일).
    var krwGeneration by remember { mutableStateOf(0) }

    val balanceDisplay = usdc?.humanizedBalance ?: "0"

    var to by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf(false) }
    var scanner by remember { mutableStateOf(false) }

    /** 공용 목록 갱신 시 USDC 잔액 기준 KRW 환산 (미보유면 "0" → ₩0). */
    suspend fun refreshKrw() {
        krwGeneration += 1
        val gen = krwGeneration
        krwText = null
        if (usdcAddr == null) {
            krwLoading = false
            return
        }
        krwLoading = true
        val amt = usdc?.humanizedBalance ?: "0"
        val krw = wallet.getKrwValue(chainId, usdcAddr, amt)
        if (gen != krwGeneration) return
        krwText = krw
        krwLoading = false
    }

    // 최초 표시 + 주소/계정/체인 변경 시 공용 목록 적재.
    LaunchedEffect(address, state.selectedAccountId, state.selectedChainId) { wallet.loadAssets() }
    // 공용 목록 갱신 시 USDC 잔액 기준 KRW 재환산.
    LaunchedEffect(state.assets) { refreshKrw() }

    SectionContainer(
        title = "결제 (Topup)",
        subtitle = "체인 ${chain?.name ?: chainId.ifEmpty { "없음" }} · USDC",
        modifier = modifier,
    ) {
        if (usdcAddr != null) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "USDC 잔액",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    when {
                        loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp)
                            Spacer(Modifier.width(6.dp))
                            Text("조회 중…", style = MaterialTheme.typography.bodySmall)
                        }
                        loadError != null -> Text(
                            loadError,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                        else -> Text("$balanceDisplay USDC", style = MaterialTheme.typography.bodyMedium)
                    }
                    when {
                        krwLoading -> Text(
                            "환산 중…",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        krwText != null -> Text(
                            krwText!!,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                TextButton(onClick = { scope.launch { wallet.loadAssets() } }, enabled = !loading) { Text("새로고침") }
            }

            Spacer(Modifier.height(8.dp))
            Text(
                usdcAddr,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
            )

            Spacer(Modifier.height(10.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = to,
                    onValueChange = { to = it },
                    label = { Text("to (SETTLEMENT 지갑)") },
                    placeholder = { Text("0x…") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = { scanner = true }) { Text("QR 스캔") }
            }
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
                label = { Text("금액 (USDC, 기본 1)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(10.dp))

            Button(
                onClick = {
                    if (to.isBlank()) return@Button
                    confirm = true
                },
                enabled = state.sdkInitialized
                    && wallet.publicKey.isNotEmpty()
                    && to.isNotBlank()
                    && !state.paymentLoading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.paymentLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                else Text("거래 확인")
            }
        } else {
            Text(
                "이 체인은 USDC topup 을 지원하지 않습니다",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
            )
        }

        state.paymentResult?.let { r ->
            Spacer(Modifier.height(8.dp))
            Text("✓ status=${r.status}", style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.size(4.dp))
            Text(
                "transactionId",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CopyableText(text = r.transactionId, singleLine = true)
            Spacer(Modifier.size(4.dp))
            Text(
                "paymentUuid",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CopyableText(text = r.paymentUuid, singleLine = true)
            if (!r.txHash.isNullOrEmpty()) {
                Spacer(Modifier.size(4.dp))
                Text(
                    "txHash",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                CopyableText(text = r.txHash, singleLine = true)
            }
            r.submittedAt?.let {
                Spacer(Modifier.size(4.dp))
                Text("submittedAt=$it", style = MaterialTheme.typography.labelSmall)
            }
        }
        state.paymentError?.let {
            Spacer(Modifier.size(8.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }

    if (scanner) {
        Dialog(
            onDismissRequest = { scanner = false },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
                QRScannerView(
                    onQRCodeScanned = { content ->
                        scanner = false
                        to = parseRecipient(content)
                    },
                    onClose = { scanner = false },
                    lifecycleOwner = lifecycleOwner,
                    modifier = Modifier.fillMaxSize(),
                )
                TextButton(
                    onClick = { scanner = false },
                    modifier = Modifier.align(Alignment.TopEnd).padding(16.dp),
                ) { Text("닫기", color = Color.White) }
            }
        }
    }

    if (confirm) {
        val effectiveAmount = amount.trim().ifEmpty { "1" }
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("결제 확인") },
            text = {
                Column {
                    ConfirmRow("받는 사람", to, mono = true)
                    ConfirmRow("금액", "$effectiveAmount USDC")
                    usdcAddr?.let { ConfirmRow("토큰", it, mono = true) }
                    (chain?.name ?: chainId.ifEmpty { null })?.let { ConfirmRow("체인", it) }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "⚠ 결제 후 되돌릴 수 없습니다.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    confirm = false
                    if (usdcAddr != null) {
                        // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
                        wallet.pay(
                            toInput = to,
                            chainIdInput = chainId,
                            tokenInput = usdcAddr,
                            amountInput = effectiveAmount,
                        )
                    }
                }) { Text("결제") }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("취소") } },
        )
    }
}

/** 체인별 USDC 컨트랙트 주소 (topup 전용 하드코딩). 미지원 체인은 null. */
private fun usdcAddress(chainId: String): String? = when (chainId) {
    "11155111" -> "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"  // Ethereum Sepolia
    "84532" -> "0x036CbD53842c5426634e7929541eC2318f3dCF7e"     // Base Sepolia
    "1" -> "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"          // Ethereum Mainnet
    "8453" -> "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"       // Base Mainnet
    else -> null
}
