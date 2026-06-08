package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.TransactionHistoryItem
import com.dsrv.wallet.example.wallet.model.Wallet

/**
 * 거래 내역 조회 — customer-backend `GET /sdk/transactions` (선택 지갑 fromAddress 기준).
 */
@Composable
fun HistorySection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val address = wallet.addressText

    // 진입 시 자동 조회 (지갑 변경 시 재조회)
    LaunchedEffect(address) {
        if (address.isNotEmpty()) wallet.getTransactionHistory()
    }

    SectionContainer(
        title = "거래 내역",
        subtitle = "총 ${state.historyTotal}건 · 지갑 ${shortHex(address)}",
        modifier = modifier,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.End,
        ) {
            if (state.historyLoading) {
                CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
            }
            TextButton(
                onClick = { wallet.getTransactionHistory() },
                enabled = state.sdkInitialized && !state.historyLoading,
            ) { Text("새로고침") }
        }

        state.historyError?.let {
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.height(6.dp))
        }

        if (state.historyItems.isEmpty() && !state.historyLoading && state.historyError == null) {
            Text(
                "거래 내역이 없습니다.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        state.historyItems.forEachIndexed { i, item ->
            HistoryItemCard(item)
            if (i < state.historyItems.lastIndex) Spacer(Modifier.height(8.dp))
        }

        if (state.historyItems.size < state.historyTotal) {
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = { wallet.getTransactionHistory(loadMore = true) },
                enabled = !state.historyLoading,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("더 보기 (${state.historyItems.size}/${state.historyTotal})") }
        }
    }
}

@Composable
private fun HistoryItemCard(item: TransactionHistoryItem) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(item.method ?: "transaction", style = MaterialTheme.typography.titleSmall)
                    Text(
                        item.createdAt,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                AssistChip(onClick = {}, label = { Text(item.status) })
            }
            Spacer(Modifier.height(6.dp))
            HorizontalDivider()
            Spacer(Modifier.height(6.dp))
            HistoryRow("체인", "${item.chainId} (${item.chainType})")
            HistoryRow("보낸 주소", shortHex(item.fromAddress))
            item.toAddress?.let { HistoryRow("받는 주소", shortHex(it)) }
            HistoryRow("txId", item.transactionId)
            item.txHash?.let {
                Spacer(Modifier.height(4.dp))
                Text("txHash", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                CopyableText(text = it, singleLine = true)
            }
        }
    }
}

@Composable
private fun HistoryRow(label: String, value: String) {
    Row(modifier = Modifier.padding(vertical = 2.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(76.dp),
        )
        Text(value, style = MaterialTheme.typography.labelMedium)
    }
}

private fun shortHex(s: String): String = if (s.length <= 16) s else "${s.take(10)}…${s.takeLast(4)}"
