package com.dsrv.wallet.example.wallet.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.model.Wallet
import com.dsrv.wallet.sdk.ChainInfo
import kotlinx.coroutines.launch

/**
 * customer-backend `POST /payments` 호출 — Topup 결제 흐름 (cross-chain).
 *
 * source(출금) / destination(수령) 의 chain·token·주소를 직접 입력할 수 있다. 비우면 기본값으로
 * 폴백(source chain=선택 체인, fromAddress=내 지갑, fromTokenAddress=체인 USDC, destination=source 와 동일).
 * USDC 잔액/KRW 행은 선택 체인 기준 참고용 표시이며, 실제 결제 토큰은 fromTokenAddress 입력이 결정한다.
 * paymentType=0/sourceUserId 는 [Wallet.pay] 가 채움.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaymentSection(modifier: Modifier = Modifier) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val lifecycleOwner = LocalContext.current as LifecycleOwner
    val scope = rememberCoroutineScope()
    val address = wallet.addressText

    val chainId = state.selectedChainId.orEmpty()
    val chain = state.chains.firstOrNull { it.chainId == chainId }
    // 결제 토큰 = 선택 체인의 USDC (하드코딩). stablecoin 측이 USDC 만 허용.
    val usdcAddr = usdcAddress(chainId)

    // 자산 목록/로딩/에러는 공용 상태(uiState)에서 관찰. KRW 만 이 컴포저블이 보관.
    val loading = state.assetsLoading
    val loadError = state.assetsError
    // 보유 USDC (공용 자산목록에서 컨트랙트 주소로 매칭). 미보유면 null → 잔액 0 표시.
    val usdc = usdcAddr?.let { addr ->
        state.assets.firstOrNull { it.contractAddress?.equals(addr, ignoreCase = true) == true }
    }
    var krwText by remember { mutableStateOf<String?>(null) }
    var krwLoading by remember { mutableStateOf(false) }
    // 빠른 체인/계정 전환·연속 새로고침 시 이전 응답이 현재 KRW 를 덮어쓰지 못하게 하는 가드 (iOS/Flutter 동일).
    var krwGeneration by remember { mutableStateOf(0) }

    val balanceDisplay = usdc?.humanizedBalance ?: "0"

    var to by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf(false) }
    var scanner by remember { mutableStateOf(false) }
    // source(출금) / destination(수령) 입력 — 비우면 기본값 폴백(placeholder 로 기본값 노출).
    var sourceChainText by remember { mutableStateOf("") }
    var fromTokenText by remember { mutableStateOf("") }
    var destChainText by remember { mutableStateOf("") }
    var destTokenText by remember { mutableStateOf("") }

    // 입력값이 비면 사용할 기본값 (= 기존 자동 도출 동작). placeholder 와 확정 전송에 함께 쓴다.
    val resolvedSourceChain = sourceChainText.ifBlank { chainId }
    // fromAddress 는 항상 현재 선택한 지갑 — 입력받지 않는다.
    val resolvedFromAddress = address
    val resolvedFromToken = fromTokenText.ifBlank { usdcAddress(resolvedSourceChain).orEmpty() }

    /** 공용 목록 갱신 시 USDC 잔액 기준 KRW 환산 (미보유면 "0" → ₩0). */
    suspend fun refreshKrw() {
        krwGeneration += 1
        val gen = krwGeneration
        krwText = null
        if (usdcAddr == null) {
            krwLoading = false
            return
        }
        krwLoading = true
        val amt = usdc?.humanizedBalance ?: "0"
        val krw = wallet.getKrwValue(chainId, usdcAddr, amt)
        if (gen != krwGeneration) return
        krwText = krw
        krwLoading = false
    }

    // 최초 표시 + 주소/계정/체인 변경 시 공용 목록 적재.
    LaunchedEffect(address, state.selectedAccountId, state.selectedChainId) { wallet.loadAssets() }
    // 공용 목록 갱신 시 USDC 잔액 기준 KRW 재환산.
    LaunchedEffect(state.assets) { refreshKrw() }

    SectionContainer(
        title = "결제 (Topup)",
        subtitle = "source → destination · 체인 ${chain?.name ?: chainId.ifEmpty { "없음" }}",
        modifier = modifier,
    ) {
        // 잔액 helper (참고용) — 선택 체인의 USDC 잔액/KRW. 결제 토큰은 아래 fromTokenAddress 입력으로 결정.
        if (usdcAddr != null) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "USDC 잔액 (선택 체인, 참고용)",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    when {
                        loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.size(12.dp), strokeWidth = 2.dp)
                            Spacer(Modifier.width(6.dp))
                            Text("조회 중…", style = MaterialTheme.typography.bodySmall)
                        }
                        loadError != null -> Text(
                            loadError,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                        else -> Text("$balanceDisplay USDC", style = MaterialTheme.typography.bodyMedium)
                    }
                    when {
                        krwLoading -> Text(
                            "환산 중…",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        krwText != null -> Text(
                            krwText!!,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                TextButton(onClick = { scope.launch { wallet.loadAssets() } }, enabled = !loading) { Text("새로고침") }
            }
            Spacer(Modifier.height(10.dp))
        }

        // ── source (출금) ── 비우면 placeholder 의 기본값 사용.
        // fromAddress 는 현재 선택한 지갑 고정 — 입력받지 않는다.
        GroupCard {
            Text(
                "source (출금)",
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.fillMaxWidth(),
            )
            ChainDropdown(
                label = "chain",
                chains = state.chains,
                selectedChainId = resolvedSourceChain,
                sameAsSourceOption = false,
                onSelect = { sourceChainText = it },
            )
            OutlinedTextField(
                value = fromTokenText,
                onValueChange = { fromTokenText = it },
                label = { Text("fromTokenAddress") },
                placeholder = { Text(usdcAddress(resolvedSourceChain) ?: "0x… (USDC)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.height(12.dp))

        // ── destination (수령) ── chain/token 비우면 source 와 동일.
        GroupCard {
            Text(
                "destination (수령)",
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = to,
                    onValueChange = { to = it },
                    label = { Text("toAddress") },
                    placeholder = { Text("0x…") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = { scanner = true }) { Text("QR 스캔") }
            }
            ChainDropdown(
                label = "chain",
                chains = state.chains,
                selectedChainId = destChainText,
                sameAsSourceOption = true,
                onSelect = { destChainText = it },
            )
            OutlinedTextField(
                value = destTokenText,
                onValueChange = { destTokenText = it },
                label = { Text("tokenAddress") },
                placeholder = { Text("source 와 동일") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.height(12.dp))

        // ── 금액 ── destination 과 구분되는 별도 그룹.
        Text(
            "금액",
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
        )
        Spacer(Modifier.height(4.dp))
        OutlinedTextField(
            value = amount,
            onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
            label = { Text("금액 (기본 1)") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))

        Button(
            onClick = {
                if (to.isBlank()) return@Button
                confirm = true
            },
            enabled = state.sdkInitialized
                && wallet.publicKey.isNotEmpty()
                && to.isNotBlank()
                && !state.paymentLoading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.paymentLoading) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
            else Text("거래 확인")
        }

        state.paymentResult?.let { r ->
            Spacer(Modifier.height(8.dp))
            Text("✓ status=${r.status}", style = MaterialTheme.typography.bodySmall)
            Spacer(Modifier.size(4.dp))
            Text(
                "transactionId",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CopyableText(text = r.transactionId, singleLine = true)
            Spacer(Modifier.size(4.dp))
            Text(
                "paymentUuid",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            CopyableText(text = r.paymentUuid, singleLine = true)
            if (!r.txHash.isNullOrEmpty()) {
                Spacer(Modifier.size(4.dp))
                Text(
                    "txHash",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                CopyableText(text = r.txHash, singleLine = true)
            }
            r.submittedAt?.let {
                Spacer(Modifier.size(4.dp))
                Text("submittedAt=$it", style = MaterialTheme.typography.labelSmall)
            }
        }
        state.paymentError?.let {
            Spacer(Modifier.size(8.dp))
            Text("⚠ $it", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
    }

    if (scanner) {
        Dialog(
            onDismissRequest = { scanner = false },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
                QRScannerView(
                    onQRCodeScanned = { content ->
                        scanner = false
                        to = parseRecipient(content)
                    },
                    onClose = { scanner = false },
                    lifecycleOwner = lifecycleOwner,
                    modifier = Modifier.fillMaxSize(),
                )
                TextButton(
                    onClick = { scanner = false },
                    modifier = Modifier.align(Alignment.TopEnd).padding(16.dp),
                ) { Text("닫기", color = Color.White) }
            }
        }
    }

    if (confirm) {
        val effectiveAmount = amount.trim().ifEmpty { "1" }
        // destination chain/token 비우면 source 와 동일하게 표시.
        val destChainDisplay = destChainText.ifBlank { resolvedSourceChain }
        val destTokenDisplay = destTokenText.ifBlank { resolvedFromToken }
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("결제 확인") },
            text = {
                Column {
                    ConfirmRow("금액", effectiveAmount)
                    Spacer(Modifier.height(6.dp))
                    ConfirmRow("source chain", resolvedSourceChain)
                    ConfirmRow("from", resolvedFromAddress, mono = true)
                    ConfirmRow("source token", resolvedFromToken, mono = true)
                    Spacer(Modifier.height(6.dp))
                    ConfirmRow("dest chain", destChainDisplay)
                    ConfirmRow("to", to, mono = true)
                    ConfirmRow("dest token", destTokenDisplay, mono = true)
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "⚠ 결제 후 되돌릴 수 없습니다.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    confirm = false
                    // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
                    // 빈 입력은 pay() / resolved* 기본값으로 폴백.
                    wallet.pay(
                        sourceChainIdInput = sourceChainText,
                        sourceTokenInput = resolvedFromToken,
                        fromInput = "",
                        destChainIdInput = destChainText,
                        destTokenInput = destTokenText,
                        toInput = to,
                        amountInput = effectiveAmount,
                    )
                }) { Text("결제") }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("취소") } },
        )
    }
}

/** source / destination 을 감싸는 옅은 카드 컨테이너. */
@Composable
private fun GroupCard(content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        content = content,
    )
}

/**
 * 가져온 chain 목록([chains]) 기반 chainId select.
 *
 * @param selectedChainId 현재 값. 빈 문자열이면 [sameAsSourceOption] 시 "source 와 동일" 로 표시.
 * @param sameAsSourceOption destination 용 — 목록 맨 위에 "source 와 동일"(빈 값) 옵션 추가.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChainDropdown(
    label: String,
    chains: List<ChainInfo>,
    selectedChainId: String,
    sameAsSourceOption: Boolean,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val sameLabel = "source 와 동일"
    val displayValue = when {
        selectedChainId.isEmpty() -> if (sameAsSourceOption) sameLabel else ""
        else -> chains.firstOrNull { it.chainId == selectedChainId }
            ?.let { "${it.name} (${it.chainId})" } ?: selectedChainId
    }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
        modifier = Modifier.fillMaxWidth(),
    ) {
        OutlinedTextField(
            value = displayValue,
            onValueChange = {},
            readOnly = true,
            label = { Text(label) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.fillMaxWidth().menuAnchor(),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            if (sameAsSourceOption) {
                DropdownMenuItem(
                    text = { Text(sameLabel) },
                    onClick = { onSelect(""); expanded = false },
                )
            }
            chains.forEach { c ->
                DropdownMenuItem(
                    text = { Text("${c.name} (${c.chainId})") },
                    onClick = { onSelect(c.chainId); expanded = false },
                )
            }
        }
    }
}

/** 체인별 USDC 컨트랙트 주소 (topup 전용 하드코딩). 미지원 체인은 null. */
private fun usdcAddress(chainId: String): String? = when (chainId) {
    "11155111" -> "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"  // Ethereum Sepolia
    "84532" -> "0x036CbD53842c5426634e7929541eC2318f3dCF7e"     // Base Sepolia
    "1" -> "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"          // Ethereum Mainnet
    "8453" -> "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"       // Base Mainnet
    else -> null
}
