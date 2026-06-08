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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.dsrv.wallet.example.wallet.config.TokenConfig
import com.dsrv.wallet.example.wallet.config.TokenInfo
import com.dsrv.wallet.example.wallet.model.BalanceClient
import com.dsrv.wallet.example.wallet.model.Wallet
import com.dsrv.wallet.example.wallet.model.fromBaseUnits
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransferSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val lifecycleOwner = LocalContext.current as LifecycleOwner

    val chain = state.chains.firstOrNull { it.chainId == state.selectedChainId }
    val chainId = state.selectedChainId.orEmpty()

    // 동적 토큰 목록 — ETH (네이티브) + 현재 체인에서 정의된 토큰 (USDC 등)
    val tokens: List<String> = remember(chainId) {
        listOf("ETH") + TokenConfig.getAvailableTokenSymbols(chainId)
    }
    var tokenIndex by remember(chainId) { mutableIntStateOf(0) }
    val safeIndex = tokenIndex.coerceIn(0, (tokens.size - 1).coerceAtLeast(0))
    val token = tokens.getOrNull(safeIndex) ?: "ETH"
    val tokenInfo: TokenInfo? = if (token == "ETH") null else TokenConfig.getToken(chainId, token)

    var recipient by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var scanner by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }

    // ===== Balance =====
    val balanceClient = remember { BalanceClient() }
    val scope = rememberCoroutineScope()
    val address = wallet.addressText
    var balanceText by remember(token, chainId, address) { mutableStateOf<String?>(null) }
    var balanceLoading by remember(token, chainId, address) { mutableStateOf(false) }
    var balanceError by remember(token, chainId, address) { mutableStateOf<String?>(null) }
    val nativeDecimals = 18

    fun refreshBalance() {
        if (chainId.isEmpty() || address.isEmpty()) {
            balanceError = "체인·지갑 없음"
            return
        }
        if (TokenConfig.getRpcUrl(chainId) == null) {
            balanceError = "이 체인의 RPC 가 등록되지 않았습니다"
            return
        }
        balanceError = null
        balanceLoading = true
        scope.launch {
            runCatching {
                if (token == "ETH") {
                    val bi = balanceClient.getNativeBalance(chainId, address)
                    fromBaseUnits(bi, nativeDecimals) + " ETH"
                } else {
                    val info = tokenInfo ?: throw IllegalStateException("토큰 정보 없음")
                    val bi = balanceClient.getErc20Balance(chainId, info.address, address)
                    fromBaseUnits(bi, info.decimals) + " $token"
                }
            }.onSuccess {
                balanceText = it
                balanceLoading = false
            }.onFailure {
                balanceError = it.message ?: "조회 실패"
                balanceLoading = false
            }
        }
    }

    // 토큰·체인·주소 변경 시 자동 조회
    LaunchedEffect(token, chainId, address) {
        if (chainId.isNotEmpty() && address.isNotEmpty()) refreshBalance()
    }

    SectionContainer(title = "전송", subtitle = "체인 ${chain?.name ?: "없음"} · $token", modifier = modifier) {
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

        TokenInfoCard(token = token, tokenInfo = tokenInfo)
        Spacer(Modifier.height(8.dp))

        BalanceRow(
            balance = balanceText,
            loading = balanceLoading,
            error = balanceError,
            onRefresh = { refreshBalance() },
        )
        Spacer(Modifier.height(10.dp))

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            OutlinedTextField(
                value = recipient,
                onValueChange = { recipient = it },
                label = { Text("받는 주소") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = { scanner = true }) { Text("QR 스캔") }
        }
        Spacer(Modifier.height(6.dp))

        val placeholder = if (token == "ETH") "0.001" else "1"
        OutlinedTextField(
            value = amount,
            onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
            label = { Text("금액 ($token, 기본 $placeholder)") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        Button(
            onClick = {
                if (recipient.isBlank()) wallet.transfer(recipient, amount, token)
                else confirm = true
            },
            enabled = state.sdkInitialized && !state.transferLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.transferLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("거래 확인")
        }

        state.lastTxHash?.let {
            Spacer(Modifier.height(6.dp))
            Text("✓ 전송 완료", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
            CopyableText(text = it, singleLine = true)
        }
        state.transferError?.let {
            Spacer(Modifier.height(6.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }

    if (scanner) {
        Dialog(onDismissRequest = { scanner = false }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
                QRScannerView(
                    onQRCodeScanned = { content ->
                        scanner = false
                        recipient = parseRecipient(content)
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
        val effectiveAmount = amount.trim().ifEmpty { if (token == "ETH") "0.001" else "1" }
        val tokenAddress = tokenInfo?.address
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("거래 확인") },
            text = {
                Column {
                    ConfirmRow("받는 사람", recipient, mono = true)
                    ConfirmRow("금액", "$effectiveAmount $token")
                    tokenAddress?.let { ConfirmRow("토큰", it, mono = true) }
                    chain?.name?.let { ConfirmRow("체인", it) }
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "⚠ 서명 후 되돌릴 수 없습니다.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    confirm = false
                    wallet.transfer(recipient, amount, token)
                }) { Text("서명 & 전송") }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("취소") } },
        )
    }
}

@Composable
private fun BalanceRow(
    balance: String?,
    loading: Boolean,
    error: String?,
    onRefresh: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "현재 잔액",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            when {
                loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(6.dp))
                    Text("조회 중…", style = MaterialTheme.typography.bodySmall)
                }
                error != null -> Text(
                    error,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
                balance != null -> Text(balance, style = MaterialTheme.typography.bodyMedium)
                else -> Text("—", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        TextButton(onClick = onRefresh, enabled = !loading) { Text("새로고침") }
    }
}

@Composable
private fun TokenInfoCard(token: String, tokenInfo: TokenInfo?) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp)) {
        if (token == "ETH") {
            Text(
                "네이티브 코인 (gas 토큰) · decimals 18",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else if (tokenInfo != null) {
            Text(
                "${tokenInfo.name} · decimals ${tokenInfo.decimals}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(tokenInfo.address, style = MaterialTheme.typography.labelSmall)
        } else {
            Text(
                "이 체인에 정의된 $token 토큰 정보가 없습니다",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.error,
            )
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

private fun parseRecipient(content: String): String {
    val raw = content.trim()
    if (raw.startsWith("ethereum:", ignoreCase = true)) {
        val rest = raw.substring("ethereum:".length)
        return rest.substringBefore("@").substringBefore("/").substringBefore("?")
    }
    return raw
}
