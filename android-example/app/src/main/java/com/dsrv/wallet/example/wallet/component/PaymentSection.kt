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
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.dsrv.wallet.example.wallet.config.TokenConfig
import com.dsrv.wallet.example.wallet.config.TokenInfo
import com.dsrv.wallet.example.wallet.model.Wallet

/**
 * customer-backend `POST /payments` 호출 — Topup 결제 흐름.
 *
 * UI 는 [TransferSection] 과 동일한 패턴 — chain 자동(selectedChainId), 토큰은 segmented row 로
 * ERC-20 토큰 목록(예: USDC) 노출. amount 는 사람 읽는 단위(humanized, 예: "1.5") 그대로 전송 —
 * wei 변환은 stablecoin Payments 측이 담당. paymentType=0, sourceUserId=wallet.userId 는
 * [Wallet.pay] 가 자동 채움.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val lifecycleOwner = LocalContext.current as LifecycleOwner

    val chain = state.chains.firstOrNull { it.chainId == state.selectedChainId }
    val chainId = state.selectedChainId.orEmpty()

    // ERC-20 토큰 목록 — 결제는 native(ETH) 결제가 의미 없으므로 ERC-20 만 노출.
    val tokens: List<String> = remember(chainId) { TokenConfig.getAvailableTokenSymbols(chainId) }
    var tokenIndex by remember(chainId) { mutableIntStateOf(0) }
    val safeIndex = tokenIndex.coerceIn(0, (tokens.size - 1).coerceAtLeast(0))
    val token = tokens.getOrNull(safeIndex)
    val tokenInfo: TokenInfo? = if (token != null) TokenConfig.getToken(chainId, token) else null

    var to by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf(false) }
    var scanner by remember { mutableStateOf(false) }

    SectionContainer(
        title = "결제 (Topup)",
        subtitle = "체인 ${chain?.name ?: "없음"} · ${token ?: "토큰 없음"}",
        modifier = modifier,
    ) {
        if (tokens.isEmpty()) {
            Text(
                "이 체인에 정의된 ERC-20 토큰이 없습니다 (TokenConfig 확인)",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
            )
        } else {
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                tokens.forEachIndexed { i, t ->
                    SegmentedButton(
                        selected = safeIndex == i,
                        onClick = { tokenIndex = i },
                        shape = SegmentedButtonDefaults.itemShape(index = i, count = tokens.size),
                    ) { Text(t) }
                }
            }
            Spacer(Modifier.height(8.dp))
            TokenInfoCard(tokenInfo)
        }

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
            label = { Text("금액 (${token ?: "토큰"}, 기본 1)") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))

        Button(
            onClick = {
                if (to.isBlank() || tokenInfo == null) return@Button
                confirm = true
            },
            enabled = state.sdkInitialized
                && wallet.publicKey.isNotEmpty()
                && tokenInfo != null
                && to.isNotBlank()
                && !state.paymentLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.paymentLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("거래 확인")
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
        val info = tokenInfo
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("결제 확인") },
            text = {
                Column {
                    ConfirmRow("받는 사람", to, mono = true)
                    ConfirmRow("금액", "$effectiveAmount ${token ?: ""}")
                    info?.address?.let { ConfirmRow("토큰", it, mono = true) }
                    chain?.name?.let { ConfirmRow("체인", it) }
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
                    if (info != null) {
                        // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
                        wallet.pay(
                            toInput = to,
                            chainIdInput = chainId,
                            tokenInput = info.address,
                            amountInput = effectiveAmount,
                        )
                    }
                }) { Text("결제") }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("취소") } },
        )
    }
}

@Composable
private fun TokenInfoCard(tokenInfo: TokenInfo?) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp)) {
        if (tokenInfo != null) {
            Text(
                "${tokenInfo.name} · decimals ${tokenInfo.decimals}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(tokenInfo.address, style = MaterialTheme.typography.labelSmall)
        }
    }
}

@Composable
private fun ConfirmRow(label: String, value: String, mono: Boolean = false) {
    Row(modifier = Modifier.padding(vertical = 3.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(80.dp),
        )
        Text(value, style = MaterialTheme.typography.labelMedium)
    }
}

/** `ethereum:0x…@chainId/…?…` 같은 EIP-681 URI 에서 순수 address 만 추출. */
private fun parseRecipient(content: String): String {
    val raw = content.trim()
    if (raw.startsWith("ethereum:", ignoreCase = true)) {
        val rest = raw.substring("ethereum:".length)
        return rest.substringBefore("@").substringBefore("/").substringBefore("?")
    }
    return raw
}
