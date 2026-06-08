package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet

@Composable
fun ChainSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState

    SectionContainer(title = "체인", subtitle = "지원 체인 · 활성 선택", modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("목록 (${state.chains.size})", style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
            if (state.chainsLoading) CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
            else TextButton(onClick = { wallet.getChainList() }, enabled = state.sdkInitialized) {
                Text("조회")
            }
        }
        Spacer(Modifier.height(4.dp))

        state.chains.forEachIndexed { i, chain ->
            val selected = state.selectedChainId == chain.chainId
            ListItem(
                headlineContent = { Text(chain.name) },
                supportingContent = {
                    Text("${chain.chainType}·${chain.networkType}·${chain.chainId}")
                },
                leadingContent = {
                    RadioButton(
                        selected = selected,
                        onClick = { wallet.selectChain(chain.chainId) },
                    )
                },
                modifier = Modifier.clickable { wallet.selectChain(chain.chainId) },
            )
            if (i < state.chains.lastIndex) HorizontalDivider()
        }

        state.chainsError?.let {
            Spacer(Modifier.height(6.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }
}
