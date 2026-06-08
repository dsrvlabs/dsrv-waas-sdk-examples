package com.dsrv.wallet.example.wallet.screen

import androidx.compose.runtime.Composable

@Composable
fun RootScreen() {
    // WalletScreen 이 Scaffold + TopAppBar 를 직접 보유하므로 패딩·배경은 그쪽에서 관리.
    WalletScreen()
}
