package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet

@Composable
fun DelegateSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val alreadyDone = state.delegateAlreadyDone && state.delegateResults.isEmpty()
    val delegateDone = alreadyDone || state.delegateResults.isNotEmpty()

    SectionContainer(title = "Delegate (EIP-7702)", subtitle = "지원 chain 일괄 broadcast", modifier = modifier) {
        Button(
            onClick = { wallet.delegate() },
            enabled = state.sdkInitialized && wallet.address.isNotEmpty() && !state.delegateLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.delegateLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text(if (alreadyDone) "다시 시도" else "Delegate")
        }

        when {
            alreadyDone -> {
                Spacer(Modifier.size(8.dp))
                Text(
                    "✓ 이미 위임됨 — 추가 작업 불필요",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            state.delegateResults.isNotEmpty() -> {
                Spacer(Modifier.size(8.dp))
                val successes = state.delegateResults.count { it.isSuccess }
                val failures = state.delegateResults.size - successes
                Text(
                    "결과: success=$successes / failed=$failures (총 ${state.delegateResults.size} chains)",
                    style = MaterialTheme.typography.bodySmall,
                )
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    state.delegateResults.forEach { item ->
                        when {
                            !item.isSuccess -> Text(
                                "✗ ${item.chainId} [${item.outcome}]: ${item.errorMessage ?: "unknown"}",
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodySmall,
                            )
                            item.txHash != null -> {
                                Text("✓ ${item.chainId} [${item.outcome}]", style = MaterialTheme.typography.bodySmall)
                                CopyableText(text = item.txHash!!, singleLine = true)
                            }
                            else -> Text(
                                // ALREADY_DELEGATED — txHash 없음
                                "✓ ${item.chainId} [${item.outcome}]",
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
            }
        }
        state.delegateError?.let {
            Spacer(Modifier.size(8.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }

        // ── 위임 해제 ─────────────────────────────────────────────
        if (delegateDone) {
            Spacer(Modifier.size(16.dp))
            HorizontalDivider()
            Spacer(Modifier.size(12.dp))
            Text("위임 해제 (Revoke)", style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.size(4.dp))
            Text(
                "지원 chain 의 위임을 해제합니다. 해제 시 페이먼트의 Approve 도 사실상 무효화됩니다.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.size(8.dp))
            OutlinedButton(
                onClick = { wallet.revoke() },
                enabled = state.sdkInitialized && wallet.address.isNotEmpty() && !state.delegateLoading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.delegateLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                else Text("Revoke", color = MaterialTheme.colorScheme.error)
            }
        }
    }
}
