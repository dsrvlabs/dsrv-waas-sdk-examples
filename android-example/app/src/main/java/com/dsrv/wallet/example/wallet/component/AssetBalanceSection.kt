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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.AssetRow
import com.dsrv.wallet.example.wallet.model.Wallet
import kotlinx.coroutines.launch

/**
 * 자산 드롭다운 + 선택 자산 잔액 + KRW 환산 — 전송 화면([TransferSection])과 지갑상세 요약카드
 * ([com.dsrv.wallet.example.wallet.screen] WalletSummaryCard)에서 공용으로 쓴다.
 *
 * 자산 목록/로딩/에러는 [Wallet.uiState](공용)에서 **관찰**하고(목록 적재는 [Wallet.loadAssets]),
 * 화면별 상태(선택 자산·KRW)만 이 컴포저블이 보관한다. 잔액은 목록의 humanizedBalance,
 * KRW 는 price-hub([Wallet.getKrwValue]). 선택된 자산은 [onSelectedAsset] 콜백으로 부모(전송)에 전달한다.
 * 표시 전용(요약카드)이면 콜백 없이 생성하면 된다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AssetBalanceSection(
    modifier: Modifier = Modifier,
    onSelectedAsset: (AssetRow?) -> Unit = {},
) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val scope = rememberCoroutineScope()
    val address = wallet.addressText

    // 자산 목록/로딩/에러는 공용 상태(uiState)에서 관찰. 선택·KRW 만 이 컴포저블이 보관.
    val assets = state.assets
    val assetsLoading = state.assetsLoading
    val assetsError = state.assetsError
    var selectedAssetId by remember { mutableStateOf<String?>(null) }
    var menuExpanded by remember { mutableStateOf(false) }

    var krwText by remember { mutableStateOf<String?>(null) }
    var krwLoading by remember { mutableStateOf(false) }
    // 빠른 선택 변경 시 이전 요청의 늦은 응답이 현재 선택의 KRW 를 덮어쓰지 못하게 하는 가드 (iOS/Flutter 동일).
    var krwGeneration by remember { mutableStateOf(0) }

    val selectedAsset = assets.firstOrNull { it.id == selectedAssetId }

    // 선택 자산의 잔액 → KRW 환산 (price-hub). 실패/미가용 시 null (잔액은 그대로 표시).
    suspend fun refreshKrw() {
        krwGeneration += 1
        val gen = krwGeneration
        krwText = null
        val asset = assets.firstOrNull { it.id == selectedAssetId }
        if (asset == null) {
            krwLoading = false
            return
        }
        krwLoading = true
        val krw = wallet.getKrwValue(asset.chainId, asset.contractAddress, asset.humanizedBalance)
        if (gen != krwGeneration) return
        krwText = krw
        krwLoading = false
    }

    // 최초 표시 + 주소/계정/체인 변경 시 공용 목록 적재.
    LaunchedEffect(address, state.selectedAccountId, state.selectedChainId) { wallet.loadAssets() }
    // 공용 목록 갱신 시 선택 보정(없으면 첫 자산) → 부모 전달 → KRW 갱신.
    LaunchedEffect(assets) {
        if (selectedAssetId == null || assets.none { it.id == selectedAssetId }) {
            selectedAssetId = assets.firstOrNull()?.id
        }
        onSelectedAsset(assets.firstOrNull { it.id == selectedAssetId })
        refreshKrw()
    }
    // 선택 자산 변경 시 KRW 즉시 갱신 + 부모에 전달.
    LaunchedEffect(selectedAssetId) {
        onSelectedAsset(assets.firstOrNull { it.id == selectedAssetId })
        refreshKrw()
    }

    Column(modifier = modifier) {
        AssetDropdown(
            assets = assets,
            loading = assetsLoading,
            error = assetsError,
            selectedAsset = selectedAsset,
            expanded = menuExpanded,
            onExpandedChange = { menuExpanded = it },
            onSelect = { selectedAssetId = it.id; menuExpanded = false },
            onRetry = { scope.launch { wallet.loadAssets() } },
            emptyText = "보유 자산이 없습니다",
        )
        Spacer(Modifier.height(8.dp))

        BalanceRow(
            asset = selectedAsset,
            krw = krwText,
            krwLoading = krwLoading,
            assetsLoading = assetsLoading,
            onRefresh = { scope.launch { wallet.loadAssets() } },
        )
    }
}

@Composable
private fun BalanceRow(
    asset: AssetRow?,
    krw: String?,
    krwLoading: Boolean,
    assetsLoading: Boolean,
    onRefresh: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "현재 잔액",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (asset != null) {
                Text("${asset.humanizedBalance} ${asset.symbol}", style = MaterialTheme.typography.bodyMedium)
                when {
                    krwLoading -> Text(
                        "환산 중…",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    krw != null -> Text(
                        krw,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                Text("—", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        TextButton(onClick = onRefresh, enabled = !assetsLoading) { Text("새로고침") }
    }
}

/**
 * WaaS 자산 목록 드롭다운 — 기존 SingleChoiceSegmentedButtonRow(ETH/USDC 하드코딩) 대체.
 * [AssetBalanceSection]/[PaymentSection] 공용. loading/error/empty 상태는 iOS Picker 와 동일하게 처리.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AssetDropdown(
    assets: List<AssetRow>,
    loading: Boolean,
    error: String?,
    selectedAsset: AssetRow?,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onSelect: (AssetRow) -> Unit,
    onRetry: () -> Unit,
    emptyText: String,
) {
    when {
        loading -> Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp)
            Spacer(Modifier.width(6.dp))
            Text("자산 조회 중…", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        error != null -> Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
            Text(error, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            TextButton(onClick = onRetry) { Text("다시 시도") }
        }
        assets.isEmpty() -> Text(
            emptyText,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        )
        else -> ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = onExpandedChange,
            modifier = Modifier.fillMaxWidth(),
        ) {
            OutlinedTextField(
                value = selectedAsset?.displayLabel ?: "",
                onValueChange = {},
                readOnly = true,
                label = { Text("자산") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier.fillMaxWidth().menuAnchor(),
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { onExpandedChange(false) }) {
                assets.forEach { asset ->
                    DropdownMenuItem(
                        text = { Text(asset.displayLabel) },
                        onClick = { onSelect(asset) },
                    )
                }
            }
        }
    }
}
