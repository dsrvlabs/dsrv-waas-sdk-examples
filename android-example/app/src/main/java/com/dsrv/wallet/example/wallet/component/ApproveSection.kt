package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet

/**
 * Approve UI — 지원 chain 전체 × project_assets 의 활성 ERC-20 을 한 번에 approve.
 * client 는 chain / token 을 명시하지 않는다 — WaaS 가 자동 결정.
 *
 * amount 는 자유 입력 — 비우면 SDK 가 "MAX" 로 처리. "0" 입력 시 Permit2 권한만 revoke.
 */
@Composable
fun ApproveSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    var amount by remember { mutableStateOf("") }

    SectionContainer(
        title = "Approve",
        subtitle = "결제 컨트랙트 multicall approve — 모든 chain × 등록 token 일괄",
        modifier = modifier,
    ) {
        Text(
            "WaaS 의 project_assets 에 등록된 활성 ERC-20 을 지원 chain 전체에 일괄 approve 합니다. " +
                "비워두면 MAX (unbounded). \"0\" 입력 시 Permit2 권한 해제.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.size(8.dp))

        OutlinedTextField(
            value = amount,
            onValueChange = { amount = it },
            label = { Text("amount (기본 MAX)") },
            placeholder = { Text("MAX") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.size(8.dp))

        Button(
            onClick = { wallet.approve(amountInput = amount) },
            enabled = state.sdkInitialized
                && wallet.publicKey.isNotEmpty()
                && !state.approveLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.approveLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("Approve")
        }

        if (state.approveResults.isNotEmpty()) {
            Spacer(Modifier.size(8.dp))
            val successes = state.approveResults.count { it.isSuccess }
            val failures = state.approveResults.size - successes
            Text(
                "결과: success=$successes / failed=$failures (총 ${state.approveResults.size} chains)",
                style = MaterialTheme.typography.bodySmall,
            )
            state.approveResults.forEach { item ->
                Spacer(Modifier.size(4.dp))
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
                        // SKIPPED / ALREADY_DELEGATED — txHash 없음
                        "✓ ${item.chainId} [${item.outcome}]",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
        state.approveError?.let {
            Spacer(Modifier.size(8.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }
}
