package com.dsrv.wallet.example.wallet.screen

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Article
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.AccountBalanceWallet
import androidx.compose.material.icons.outlined.Backup
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Payments
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dsrv.wallet.example.wallet.component.AccountSection
import com.dsrv.wallet.example.wallet.component.ApproveSection
import com.dsrv.wallet.example.wallet.component.BackupSection
import com.dsrv.wallet.example.wallet.component.ChainSection
import com.dsrv.wallet.example.wallet.component.DelegateSection
import com.dsrv.wallet.example.wallet.component.HistorySection
import com.dsrv.wallet.example.wallet.component.LogSection
import com.dsrv.wallet.example.wallet.component.PaymentSection
import com.dsrv.wallet.example.wallet.component.QRCodeView
import com.dsrv.wallet.example.wallet.component.RestoreSection
import com.dsrv.wallet.example.wallet.component.TransferSection
import com.dsrv.wallet.example.wallet.model.Wallet

// ──────────────────────────────────────────────────────────────
// 화면 라우팅
// ──────────────────────────────────────────────────────────────

private sealed class AppScreen {
    data object Login : AppScreen()
    data object WalletList : AppScreen()
    data object WalletDetail : AppScreen()

    sealed class Feature(val title: String) : AppScreen() {
        data object Query : Feature("지갑 조회")
        data object SmartAccount : Feature("스마트어카운트")
        data object Backup : Feature("백업 / 복원")
        data object Transfer : Feature("전송")
        data object History : Feature("거래 내역")
        data object Payment : Feature("결제")
        data object Log : Feature("로그")
    }
}

@Composable
fun WalletScreen() {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState

    var screen by remember { mutableStateOf<AppScreen>(AppScreen.Login) }

    LaunchedEffect(wallet.userId) {
        if (wallet.userId.isBlank()) screen = AppScreen.Login
    }
    LaunchedEffect(state.sdkInitialized) {
        if (!state.sdkInitialized && screen !is AppScreen.Login) {
            screen = if (wallet.userId.isBlank()) AppScreen.Login else AppScreen.WalletList
        }
    }
    LaunchedEffect(wallet.publicKey) {
        if (wallet.publicKey.isEmpty() && (screen is AppScreen.WalletDetail || screen is AppScreen.Feature)) {
            screen = AppScreen.WalletList
        }
    }

    when (val s = screen) {
        is AppScreen.Login -> LoginScreen(
            onLogin = { screen = AppScreen.WalletList },
        )
        is AppScreen.WalletList -> WalletListScreen(
            onBack = { screen = AppScreen.Login },
            onWalletSelected = { screen = AppScreen.WalletDetail },
        )
        is AppScreen.WalletDetail -> WalletDetailScreen(
            onBack = { screen = AppScreen.WalletList },
            onFeature = { screen = it },
        )
        is AppScreen.Feature -> FeatureScreen(
            feature = s,
            onBack = { screen = AppScreen.WalletDetail },
        )
    }
}

// ──────────────────────────────────────────────────────────────
// Screen 1: Login
// ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LoginScreen(onLogin: () -> Unit) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState

    var input by remember { mutableStateOf(wallet.userId) }
    var loginAttempted by remember { mutableStateOf(false) }
    val derivedUuid = remember(input) {
        val trimmed = input.trim()
        if (trimmed.isEmpty()) "" else Wallet.userIdToUuid(trimmed)
    }

    LaunchedEffect(state.sdkInitialized, loginAttempted) {
        if (loginAttempted && state.sdkInitialized) onLogin()
    }

    Scaffold(
        topBar = { TopAppBar(title = { Text("로그인") }) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            Text("사용자 식별", style = MaterialTheme.typography.titleLarge)
            Spacer(Modifier.height(4.dp))
            Text(
                "임의의 userId 를 입력하면 결정적 UUID 가 생성됩니다.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))

            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    OutlinedTextField(
                        value = input,
                        onValueChange = { input = it },
                        label = { Text("userId") },
                        placeholder = { Text("예: alice@example.com") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(12.dp))
                    Text("생성된 UUID", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(
                        text = derivedUuid.ifEmpty { "userId 를 입력하세요" },
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
            Text("SDK / 백엔드", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(12.dp)) {
                    KeyValueRow("SDK ID", wallet.sdkId)
                    KeyValueRow("Backend", wallet.customerBackendUrl)
                }
            }

            Spacer(Modifier.height(24.dp))
            Button(
                onClick = {
                    val trimmed = input.trim()
                    if (trimmed.isNotEmpty()) {
                        loginAttempted = true
                        if (trimmed != wallet.userId) wallet.changeUserId(trimmed)
                        if (state.sdkInitialized) onLogin() else wallet.retryInitialize()
                    }
                },
                enabled = derivedUuid.isNotEmpty() && !state.sdkInitializing,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.sdkInitializing) {
                    CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(8.dp))
                    Text("초기화 중…")
                } else {
                    Text("로그인")
                }
            }

            state.sdkInitError?.let {
                Spacer(Modifier.height(8.dp))
                Text("⚠ $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }

            if (wallet.userId.isNotBlank()) {
                Spacer(Modifier.height(24.dp))
                OutlinedButton(
                    onClick = { wallet.resetWallet(); input = "" },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("저장된 사용자 초기화") }
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────
// Screen 2: WalletList
// ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WalletListScreen(
    onBack: () -> Unit,
    onWalletSelected: () -> Unit,
) {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState

    BackHandler(onBack = onBack)

    LaunchedEffect(state.sdkInitialized) {
        if (state.sdkInitialized && state.accounts.isEmpty() && !state.accountsLoading) {
            wallet.getAccountList()
        }
    }

    val canProceed = wallet.publicKey.isNotEmpty()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("지갑 선택")
                        Text(
                            "userId: ${wallet.userId.ifEmpty { "(none)" }}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "뒤로")
                    }
                },
            )
        },
        bottomBar = {
            Surface(
                tonalElevation = 3.dp,
                modifier = Modifier.windowInsetsPadding(WindowInsets.navigationBars),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                ) {
                    if (canProceed) {
                        Text(
                            "선택된 지갑: ${shortHex(wallet.addressText)}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(6.dp))
                    }
                    Button(
                        onClick = onWalletSelected,
                        enabled = canProceed,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (canProceed) "선택" else "지갑을 먼저 선택하세요")
                    }
                }
            }
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            ChainSection()
            Spacer(Modifier.height(12.dp))
            AccountSection()
            Spacer(Modifier.height(24.dp))
        }
    }
}

// ──────────────────────────────────────────────────────────────
// Screen 3: WalletDetail
// ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WalletDetailScreen(
    onBack: () -> Unit,
    onFeature: (AppScreen.Feature) -> Unit,
) {
    val wallet: Wallet = viewModel()

    BackHandler(onBack = onBack)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("지갑 상세") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "뒤로")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            WalletSummaryCard(wallet)
            Spacer(Modifier.height(16.dp))

            Text("기능 테스트", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            FeatureMenu(onSelect = onFeature)
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun WalletSummaryCard(wallet: Wallet) {
    val context = LocalContext.current
    val state = wallet.uiState
    val account = state.accounts.firstOrNull { it.accountId == state.selectedAccountId }
    val chainName = state.chains.firstOrNull { it.chainId == state.selectedChainId }?.name
    val address = wallet.addressText
    var qrOpen by remember { mutableStateOf(false) }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(account?.label ?: "(계정 없음)", style = MaterialTheme.typography.titleMedium)
                    Text(
                        account?.let { "id ${shortHex(it.accountId)}" } ?: "계정 미선택",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                chainName?.let { AssistChip(onClick = {}, label = { Text(it) }) }
            }

            Spacer(Modifier.height(12.dp))
            Text("지갑 주소", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(address.ifEmpty { "(지갑 미발급)" }, style = MaterialTheme.typography.bodyMedium)

            if (address.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            val clip = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clip.setPrimaryClip(ClipData.newPlainText("address", address))
                            Toast.makeText(context, "복사됨", Toast.LENGTH_SHORT).show()
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("주소 복사") }
                    OutlinedButton(
                        onClick = { qrOpen = true },
                        modifier = Modifier.weight(1f),
                    ) { Text("QR") }
                }
            }
        }
    }

    if (qrOpen) {
        AlertDialog(
            onDismissRequest = { qrOpen = false },
            title = { Text("내 지갑 주소") },
            text = {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    QRCodeView(content = address, size = 220.dp)
                    Spacer(Modifier.height(8.dp))
                    Text(address, style = MaterialTheme.typography.labelSmall)
                }
            },
            confirmButton = { TextButton(onClick = { qrOpen = false }) { Text("닫기") } },
        )
    }
}

private data class FeatureItem(
    val target: AppScreen.Feature,
    val icon: ImageVector,
    val description: String,
)

private val FEATURE_ITEMS = listOf(
    FeatureItem(AppScreen.Feature.Query, Icons.Outlined.AccountBalanceWallet, "지갑 주소·체인 정보"),
    FeatureItem(AppScreen.Feature.SmartAccount, Icons.Outlined.VerifiedUser, "위임(EIP-7702) · 승인"),
    FeatureItem(AppScreen.Feature.Backup, Icons.Outlined.Backup, "백업 · 복원 · 키 갱신"),
    FeatureItem(AppScreen.Feature.Transfer, Icons.AutoMirrored.Outlined.Send, "ETH · ERC-20 전송"),
    FeatureItem(AppScreen.Feature.History, Icons.Outlined.History, "거래 내역 조회"),
    FeatureItem(AppScreen.Feature.Payment, Icons.Outlined.Payments, "Topup 결제"),
    FeatureItem(AppScreen.Feature.Log, Icons.AutoMirrored.Outlined.Article, "SDK · backend trace"),
)

@Composable
private fun FeatureMenu(onSelect: (AppScreen.Feature) -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column {
            FEATURE_ITEMS.forEachIndexed { i, item ->
                ListItem(
                    headlineContent = { Text(item.target.title) },
                    supportingContent = { Text(item.description) },
                    leadingContent = { Icon(item.icon, contentDescription = null) },
                    trailingContent = {
                        Icon(Icons.Outlined.ChevronRight, contentDescription = null)
                    },
                    modifier = Modifier.clickable { onSelect(item.target) },
                )
                if (i < FEATURE_ITEMS.lastIndex) HorizontalDivider()
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────
// Feature sub-screens
// ──────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FeatureScreen(feature: AppScreen.Feature, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(feature.title) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "뒤로")
                    }
                },
            )
        },
    ) { padding ->
        if (feature is AppScreen.Feature.Log) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(16.dp),
            ) {
                LogSection(modifier = Modifier.fillMaxWidth().weight(1f))
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                when (feature) {
                    AppScreen.Feature.Query -> QueryFeature()
                    AppScreen.Feature.SmartAccount -> SmartAccountFeature()
                    AppScreen.Feature.Backup -> BackupFeature()
                    AppScreen.Feature.Transfer -> TransferFeature()
                    AppScreen.Feature.History -> HistoryFeature()
                    AppScreen.Feature.Payment -> PaymentFeature()
                    AppScreen.Feature.Log -> Unit
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

// ── 지갑 조회 ────────────────────────────────────────────────────
@Composable
private fun QueryFeature() {
    val wallet: Wallet = viewModel()
    val state = wallet.uiState
    val context = LocalContext.current
    val address = wallet.addressText
    val chain = state.chains.firstOrNull { it.chainId == state.selectedChainId }

    Text("주소 정보", style = MaterialTheme.typography.titleSmall)
    Spacer(Modifier.height(8.dp))
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp)) {
            KeyValueRow("Public Key", wallet.publicKey)
            KeyValueRow("Address", address)
            KeyValueRow("Chain", chain?.let { "${it.name} (${it.chainId})" } ?: "(미선택)")
            chain?.let { KeyValueRow("Type", "${it.chainType} / ${it.networkType}") }
        }
    }

    Spacer(Modifier.height(12.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton(
            onClick = {
                val clip = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clip.setPrimaryClip(ClipData.newPlainText("address", address))
                Toast.makeText(context, "주소 복사됨", Toast.LENGTH_SHORT).show()
            },
            enabled = address.isNotEmpty(),
            modifier = Modifier.weight(1f),
        ) { Text("주소 복사") }
        OutlinedButton(
            onClick = { wallet.getAccountList() },
            enabled = state.sdkInitialized && !state.accountsLoading,
            modifier = Modifier.weight(1f),
        ) {
            if (state.accountsLoading) CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp)
            else Text("계정 새로고침")
        }
    }

    if (address.isNotEmpty()) {
        Spacer(Modifier.height(16.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(16.dp).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                QRCodeView(content = address, size = 200.dp)
                Spacer(Modifier.height(8.dp))
                Text(address, style = MaterialTheme.typography.labelSmall)
            }
        }
    }

    Spacer(Modifier.height(16.dp))
    Text(
        "ⓘ 잔액 조회는 RPC 직접 호출이 필요합니다.",
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

// ── 스마트어카운트 ─────────────────────────────────────────────────
@Composable
private fun SmartAccountFeature() {
    DelegateSection()
    Spacer(Modifier.height(12.dp))
    ApproveSection()
}

// ── 백업 / 복원 ──────────────────────────────────────────
@Composable
private fun BackupFeature() {
    Text("키 관리", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    Spacer(Modifier.height(8.dp))
    BackupSection()
    Spacer(Modifier.height(12.dp))
    RestoreSection()
}

// ── 전송 ─────────────────────────────────────────────────────────
@Composable
private fun TransferFeature() {
    val wallet: Wallet = viewModel()
    val walletDone = wallet.publicKey.isNotEmpty()

    if (!walletDone) {
        InfoBanner("지갑을 먼저 선택하세요.")
        return
    }
    TransferSection()
}

// ── 거래 내역 (customer-backend GET /sdk/transactions) ──────────
@Composable
private fun HistoryFeature() {
    val wallet: Wallet = viewModel()
    val walletDone = wallet.publicKey.isNotEmpty()

    if (!walletDone) {
        InfoBanner("지갑을 먼저 선택하세요.")
        return
    }
    HistorySection()
}

// ── 결제 (customer-backend POST /payments) ─────────────────────
@Composable
private fun PaymentFeature() {
    val wallet: Wallet = viewModel()
    val walletDone = wallet.publicKey.isNotEmpty()

    if (!walletDone) {
        InfoBanner("지갑을 먼저 선택하세요.")
        return
    }
    PaymentSection()
}


// ──────────────────────────────────────────────────────────────
// 공용 유틸
// ──────────────────────────────────────────────────────────────

@Composable
private fun KeyValueRow(label: String, value: String) {
    Row(modifier = Modifier.padding(vertical = 3.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(82.dp),
        )
        Text(value, style = MaterialTheme.typography.labelMedium, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun InfoBanner(text: String) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Text(text, modifier = Modifier.padding(12.dp), style = MaterialTheme.typography.bodySmall)
    }
}


private fun shortHex(s: String): String = if (s.length <= 16) s else "${s.take(10)}…${s.takeLast(4)}"

