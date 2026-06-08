package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet

@Composable
fun RestoreSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val activity = LocalContext.current as? FragmentActivity

    SectionContainer(
        title = "복원",
        subtitle = "BlockStore + Passkey 로 키 share 복원",
        modifier = modifier,
    ) {
        Text(
            "BlockStore 에 보관된 share 를 일괄 복원. Passkey 인증이 필요할 수 있습니다.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { activity?.let { wallet.restore(it) } },
            enabled = state.sdkInitialized && activity != null && !state.restoreLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.restoreLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("복원")
        }
        state.restoreResult?.let {
            Spacer(Modifier.height(6.dp))
            Text("✓ $it", style = MaterialTheme.typography.bodySmall)
        }
        state.restoreError?.let {
            Spacer(Modifier.height(6.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }
}
