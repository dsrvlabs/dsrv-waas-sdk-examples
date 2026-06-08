package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet

@Composable
fun BackupSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val activity = LocalContext.current as? FragmentActivity

    SectionContainer(
        title = "백업",
        subtitle = "BlockStore + Passkey 로 키 share 보관",
        modifier = modifier,
    ) {
        Text(
            "PENDING 상태인 share (tb_pending_backup) 를 BlockStore 로 일괄 sync. Passkey 인증이 필요할 수 있습니다.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { activity?.let { wallet.backup(it) } },
            enabled = state.sdkInitialized && activity != null && !state.backupLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.backupLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("백업")
        }
        state.backupResult?.let {
            Spacer(Modifier.height(6.dp))
            Text("✓ $it", style = MaterialTheme.typography.bodySmall)
        }
        state.backupError?.let {
            Spacer(Modifier.height(6.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }

        Spacer(Modifier.height(16.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))

        Text(
            "디버그",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = { wallet.dumpBlockStore() },
            enabled = state.sdkInitialized,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Block Store dump")
        }
        Spacer(Modifier.height(8.dp))
        OutlinedButton(
            onClick = { wallet.clearBackup() },
            enabled = state.sdkInitialized,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Backup 전체 삭제", color = MaterialTheme.colorScheme.error)
        }

        state.blockStoreDump?.let { dump ->
            Spacer(Modifier.height(10.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(10.dp)
            ) {
                Text(
                    text = dump,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier.verticalScroll(rememberScrollState())
                )
            }
        }
    }
}
