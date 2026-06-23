package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet
import com.dsrv.wallet.sdk.ChainSetupStatus

/**
 * Setup status UI — 선택된 지갑의 chain 별 위임(EIP-7702)/승인(Permit2) 상태를 read-only 로 표시.
 * 화면 진입·선택 지갑 변경 시 자동 조회되며, approve/revoke/delegate 후에도 [Wallet.getSetupStatus] 가
 * 자동 호출되어 갱신된다. [새로고침] 버튼으로 수동 갱신도 가능하다.
 */
@Composable
fun SetupStatusSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState

    // 진입 및 선택 지갑/계정 변경 시 자동 조회 — stale 한 이전 승인 내역이 남지 않도록.
    LaunchedEffect(wallet.address, state.selectedAccountId) {
        if (state.sdkInitialized && wallet.address.isNotEmpty()) wallet.getSetupStatus()
    }

    SectionContainer(
        title = "위임 / 승인 상태",
        subtitle = "chain 별 delegated · approved · token allowance",
        modifier = modifier,
    ) {
        OutlinedButton(
            onClick = { wallet.getSetupStatus() },
            enabled = state.sdkInitialized && wallet.address.isNotEmpty() && !state.setupStatusLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.setupStatusLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("새로고침")
        }

        if (state.setupStatus.isNotEmpty()) {
            Spacer(Modifier.size(8.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                state.setupStatus.forEachIndexed { idx, chain ->
                    ChainSetupStatusRow(chain)
                    if (idx < state.setupStatus.lastIndex) HorizontalDivider()
                }
            }
        } else if (!state.setupStatusLoading && state.setupStatusError == null) {
            Spacer(Modifier.size(8.dp))
            Text(
                "조회된 상태 없음 — [새로고침] 또는 approve/delegate 후 자동 갱신됩니다.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        state.setupStatusError?.let {
            Spacer(Modifier.size(8.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun ChainSetupStatusRow(chain: ChainSetupStatus) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            "chain ${chain.chainId} · delegated=${chain.delegated}",
            style = MaterialTheme.typography.bodyMedium,
        )
        chain.approvals.forEach { approval ->
            Text(
                "• ${approval.token.take(10)}…${approval.token.takeLast(6)} " +
                    "[${if (approval.approved) "✓" else "✗"}] amount=${approval.amount} exp=${approval.expiration} " +
                    "erc20=${approval.erc20Allowance}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 8.dp, top = 2.dp),
            )
        }
    }
}
