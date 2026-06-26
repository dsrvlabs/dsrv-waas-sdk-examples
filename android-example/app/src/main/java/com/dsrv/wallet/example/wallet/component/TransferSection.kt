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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
import com.dsrv.wallet.example.wallet.model.AssetRow
import com.dsrv.wallet.example.wallet.model.Wallet

@Composable
fun TransferSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val lifecycleOwner = LocalContext.current as LifecycleOwner

    // 자산 드롭다운 + 잔액 + KRW 는 공용 AssetBalanceSection 가 담당. 여기선 선택된 자산만 받아 전송에 사용.
    var selectedAsset by remember { mutableStateOf<AssetRow?>(null) }
    val chain = state.chains.firstOrNull { it.chainId == selectedAsset?.chainId }

    var recipient by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var scanner by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf(false) }

    SectionContainer(
        title = "전송",
        subtitle = "체인 ${chain?.name ?: selectedAsset?.chainId ?: "없음"} · ${selectedAsset?.symbol ?: "자산 없음"}",
        modifier = modifier,
    ) {
        AssetBalanceSection(onSelectedAsset = { selectedAsset = it })
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

        val isNative = selectedAsset?.isNative ?: true
        val sym = selectedAsset?.symbol ?: "토큰"
        val placeholder = if (isNative) "0.001" else "1"
        OutlinedTextField(
            value = amount,
            onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
            label = { Text("금액 ($sym, 기본 $placeholder)") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        Button(
            onClick = {
                // 빈 recipient / 자산 미선택 시 confirm 자체를 열지 않음.
                // enabled 조건과 중복되지만 race 보호용 가드.
                if (recipient.isBlank() || selectedAsset == null) return@Button
                confirm = true
            },
            enabled = state.sdkInitialized
                && !state.transferLoading
                && recipient.isNotBlank()
                && selectedAsset != null,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.transferLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("거래 확인")
        }

        // 전송 결과 — txHash (있을 때) + status + batchTxId (있을 때).
        // bundler 경로 (GS_ON) 에선 txHash 가 null 이고 status="SIGNED" + batchTxId 가 채워짐.
        if (state.lastTxHash != null || state.lastTxStatus != null || state.lastBatchTxId != null) {
            Spacer(Modifier.height(6.dp))
            Text("✓ 전송 결과", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.bodySmall)
            state.lastTxHash?.let {
                Text("TxHash", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                CopyableText(text = it, singleLine = true)
            }
            state.lastTxStatus?.let {
                Text("Status: $it", style = MaterialTheme.typography.bodySmall)
            }
            state.lastBatchTxId?.let {
                Text("BatchTxId", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                CopyableText(text = it, singleLine = true)
            }
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
        val isNative = selectedAsset?.isNative ?: true
        val effectiveAmount = amount.trim().ifEmpty { if (isNative) "0.001" else "1" }
        val sym = selectedAsset?.symbol ?: ""
        val contract = selectedAsset?.contractAddress
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("거래 확인") },
            text = {
                Column {
                    ConfirmRow("받는 사람", recipient, mono = true)
                    ConfirmRow("금액", "$effectiveAmount $sym")
                    contract?.let { ConfirmRow("토큰", it, mono = true) }
                    (chain?.name ?: selectedAsset?.chainId)?.let { ConfirmRow("체인", it) }
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
                    val asset = selectedAsset ?: return@TextButton
                    wallet.transfer(
                        recipientInput = recipient,
                        amountInput = amount,
                        chainId = asset.chainId,
                        contractAddress = asset.contractAddress,
                        decimals = asset.decimals,
                        symbol = asset.symbol,
                    )
                }) { Text("서명 & 전송") }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("취소") } },
        )
    }
}

@Composable
internal fun ConfirmRow(label: String, value: String, mono: Boolean = false) {
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

internal fun parseRecipient(content: String): String {
    val raw = content.trim()
    if (raw.startsWith("ethereum:", ignoreCase = true)) {
        val rest = raw.substring("ethereum:".length)
        return rest.substringBefore("@").substringBefore("/").substringBefore("?")
    }
    return raw
}
