import 'package:flutter/material.dart';

import '../wallet_state.dart';
import 'feature_screen.dart';
import 'login_screen.dart';
import 'wallet_detail_screen.dart';
import 'wallet_list_screen.dart';

/// 앱 최상위 네비게이션 — Android `WalletScreen.kt` 의 sealed class 라우팅 대응.
/// Login → WalletList → WalletDetail → Feature 의 4단계 드릴다운 흐름을 관리한다.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

enum _Stage { login, walletList, walletDetail, feature }

class _RootScreenState extends State<RootScreen> {
  final wallet = WalletState();
  _Stage _stage = _Stage.login;
  FeatureKind _feature = FeatureKind.query;

  @override
  void initState() {
    super.initState();
    wallet.loadUserIdFromStorage();
  }

  @override
  void dispose() {
    wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) {
        // 상태 기반 가드 (Android 의 LaunchedEffect 대응):
        //  - userId 비면 항상 Login
        //  - 지갑(publicKey) 없으면 Detail/Feature 진입 불가 → WalletList 로 강등
        var stage = _stage;
        if (wallet.userId.isEmpty) {
          stage = _Stage.login;
        } else if (wallet.publicKey.isEmpty &&
            (stage == _Stage.walletDetail || stage == _Stage.feature)) {
          stage = _Stage.walletList;
        }

        switch (stage) {
          case _Stage.login:
            return LoginScreen(
              wallet: wallet,
              onLogin: () => setState(() => _stage = _Stage.walletList),
            );
          case _Stage.walletList:
            return WalletListScreen(
              wallet: wallet,
              onBack: () => wallet.resetWallet(), // userId 비워짐 → Login 으로 가드
              onWalletSelected: () =>
                  setState(() => _stage = _Stage.walletDetail),
            );
          case _Stage.walletDetail:
            return WalletDetailScreen(
              wallet: wallet,
              onBack: () => setState(() => _stage = _Stage.walletList),
              onFeature: (f) => setState(() {
                _feature = f;
                _stage = _Stage.feature;
              }),
            );
          case _Stage.feature:
            return FeatureScreen(
              wallet: wallet,
              feature: _feature,
              onBack: () => setState(() => _stage = _Stage.walletDetail),
            );
        }
      },
    );
  }
}
