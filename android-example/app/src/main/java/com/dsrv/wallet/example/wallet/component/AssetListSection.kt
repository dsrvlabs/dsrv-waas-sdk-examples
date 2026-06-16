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
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.AssetRow
import com.dsrv.wallet.example.wallet.model.Wallet
import kotlinx.coroutines.launch

/**
 * 보유 자산 '전체'를 리스트로 펼쳐 조회 — 선택 체인의 모든 자산을 한 번에 표시(자산별 잔액 + KRW).
 * 전송 화면의 드롭다운([AssetBalanceSection], 선택 1건)과 달리, 여기선 전 자산을 한눈에 본다.
 *
 * 자산 목록/로딩/에러는 [Wallet.uiState](공용)에서 관찰하고(목록 적재는 [Wallet.loadAssets]),
 * 자산별 KRW 맵만 이 컴포저블이 보관한다. 잔액은 목록의 humanizedBalance(즉시 표시),
 * KRW 는 price-hub([Wallet.getKrwValue])를 자산별로 호출해 채워 넣는다(비동기). [AssetListView.swift] 미러링.
 */
@Composable
fun AssetListSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val scope = rememberCoroutineScope()
    val address = wallet.addressText
    val chainName = state.chains.firstOrNull { it.chainId == state.selectedChainId }?.name

    // 자산 목록/로딩/에러는 공용 상태(uiState)에서 관찰. KRW 맵만 이 컴포저블이 보관.
    val rows = state.assets
    val loading = state.assetsLoading
    val loadError = state.assetsError
    // 자산별 KRW 환산 문자열 (AssetRow.id → "₩...").
    val krwById = remember { mutableStateMapOf<String, String>() }
    // 비동기 KRW 채우기가 직전 로드 결과에만 반영되도록 하는 가드.
    var generation by remember { mutableStateOf(0) }

    // 현재 공용 목록(uiState.assets)의 각 자산 KRW 환산. 자산별로 채워진다.
    suspend fun loadKrw(assets: List<AssetRow>) {
        generation += 1
        val gen = generation
        krwById.clear()
        for (row in assets) {
            val krw = wallet.getKrwValue(row.chainId, row.contractAddress, row.humanizedBalance)
            if (gen != generation) return
            if (krw != null) krwById[row.id] = krw
        }
    }

    // 최초 표시 + 주소/계정/체인 변경 시 공용 목록 적재.
    LaunchedEffect(address, state.selectedAccountId, state.selectedChainId) { wallet.loadAssets() }
    // 공용 목록 갱신 시 자산별 KRW 재조회.
    LaunchedEffect(rows) { loadKrw(rows) }

    SectionContainer(
        title = "보유 자산",
        subtitle = "체인 ${chainName ?: state.selectedChainId ?: "없음"}",
        modifier = modifier,
    ) {
        when {
            loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp)
                Spacer(Modifier.width(6.dp))
                Text(
                    "자산 조회 중…",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            loadError != null -> Column {
                Text(loadError, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                TextButton(onClick = { scope.launch { wallet.loadAssets() } }) { Text("다시 시도") }
            }
            rows.isEmpty() -> Text(
                "보유 자산이 없습니다",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            else -> rows.forEachIndexed { i, row ->
                AssetRowItem(row = row, krw = krwById[row.id])
                if (i < rows.lastIndex) HorizontalDivider()
            }
        }

        Spacer(Modifier.height(8.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(onClick = { scope.launch { wallet.loadAssets() } }, enabled = !loading) { Text("새로고침") }
        }
    }
}

@Composable
private fun AssetRowItem(row: AssetRow, krw: String?) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            row.symbol,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        // 잔액(위) + KRW(아래) 우측 정렬.
        Column(horizontalAlignment = Alignment.End) {
            Text(row.humanizedBalance, style = MaterialTheme.typography.bodyMedium)
            if (krw != null) {
                Text(
                    krw,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
