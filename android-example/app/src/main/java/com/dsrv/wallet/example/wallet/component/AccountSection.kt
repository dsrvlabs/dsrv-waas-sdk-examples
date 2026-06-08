package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet
import com.dsrv.wallet.sdk.AccountInfo
import com.dsrv.wallet.sdk.AddressInfo

@Composable
fun AccountSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    var createAccountDialog by remember { mutableStateOf(false) }
    var addWalletDialog by remember { mutableStateOf<String?>(null) }

    SectionContainer(title = "계정 & 지갑", subtitle = "계정 생성·지갑 발급", modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("계정 (${state.accounts.size})", style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f))
            if (state.accountsLoading) CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
            else TextButton(onClick = { wallet.getAccountList() }, enabled = state.sdkInitialized) {
                Text("조회")
            }
            TextButton(
                onClick = { createAccountDialog = true },
                enabled = state.sdkInitialized && !state.createAccountLoading,
            ) {
                if (state.createAccountLoading) CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
                else Text("+ 계정")
            }
        }
        Spacer(Modifier.height(4.dp))

        if (state.accounts.isEmpty()) {
            Text(
                if (state.accountsLoading) "불러오는 중…" else "계정 없음 — [+ 계정] 으로 생성",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = 8.dp),
            )
        } else {
            state.accounts.forEachIndexed { idx, acc ->
                AccountSectionHeader(account = acc, onAddWallet = { addWalletDialog = acc.accountId })
                if (acc.addresses.isEmpty()) {
                    Text(
                        "지갑 없음",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 16.dp, top = 4.dp, bottom = 4.dp),
                    )
                } else {
                    acc.addresses.forEach { addr ->
                        WalletItemRow(
                            address = addr,
                            selected = addr.address.equals(wallet.address, ignoreCase = true),
                            onClick = {
                                wallet.selectAccount(acc.accountId)
                                wallet.selectWallet(addr.address)
                            },
                        )
                    }
                }
                if (idx < state.accounts.lastIndex) HorizontalDivider()
            }
        }

        (state.createAccountError ?: state.accountsError)?.let {
            Spacer(Modifier.height(6.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }

    if (createAccountDialog) {
        LabelDialog(
            title = "새 계정",
            description = "label 을 입력하세요 (비우면 자동 생성)",
            onDismiss = { createAccountDialog = false },
            onConfirm = {
                wallet.createAccount(it)
                createAccountDialog = false
            },
        )
    }

    addWalletDialog?.let { accountId ->
        LabelDialog(
            title = "새 지갑",
            description = "label 을 입력하세요 (비우면 자동 생성)",
            onDismiss = { addWalletDialog = null },
            onConfirm = {
                wallet.createAddress(accountIdInput = accountId, labelInput = it)
                addWalletDialog = null
            },
        )
    }
}

@Composable
private fun AccountSectionHeader(account: AccountInfo, onAddWallet: () -> Unit) {
    ListItem(
        headlineContent = { Text(account.label) },
        supportingContent = { Text("id ${shortId(account.accountId)} · ${account.addresses.size} wallets") },
        trailingContent = {
            TextButton(onClick = onAddWallet) { Text("+ 지갑") }
        },
    )
}

@Composable
private fun WalletItemRow(address: AddressInfo, selected: Boolean, onClick: () -> Unit) {
    val display = "${address.address.take(10)}…${address.address.takeLast(6)}"

    ListItem(
        headlineContent = { Text(display) },
        supportingContent = address.label?.takeIf { it.isNotBlank() }?.let { { Text(it) } },
        leadingContent = {
            RadioButton(selected = selected, onClick = onClick)
        },
        modifier = Modifier.clickable(onClick = onClick),
    )
}

@Composable
private fun LabelDialog(
    title: String,
    description: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    var label by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                Text(
                    description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = label,
                    onValueChange = { label = it },
                    label = { Text("label") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = { TextButton(onClick = { onConfirm(label) }) { Text("생성") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("취소") } },
    )
}

private fun shortId(id: String): String =
    if (id.length <= 12) id else "${id.take(8)}…${id.takeLast(4)}"
