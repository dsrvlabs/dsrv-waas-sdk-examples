package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dsrv.wallet.example.wallet.model.Wallet

@Composable
fun LogSection(
    modifier: Modifier = Modifier,
    wallet: Wallet = androidx.lifecycle.viewmodel.compose.viewModel(),
) {
    val logs = wallet.uiState.logs
    val scroll = rememberScrollState()

    LaunchedEffect(logs.size) { scroll.animateScrollTo(scroll.maxValue) }

    SectionContainer(title = "로그", subtitle = "SDK / backend trace", modifier = modifier) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                "${logs.size} lines",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            if (logs.isNotEmpty()) TextButton(onClick = { wallet.clearLogs() }) {
                Text("Clear")
            }
        }
        Spacer(Modifier.heightIn(min = 4.dp))
        SelectionContainer(modifier = Modifier.fillMaxWidth().weight(1f)) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp)
                    .verticalScroll(scroll),
            ) {
                if (logs.isEmpty()) {
                    Text(
                        "(no logs)",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else logs.forEach {
                    Text(it, style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
