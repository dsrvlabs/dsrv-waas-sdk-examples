import 'package:flutter/material.dart';

import '../components/account_section.dart';
import '../components/chain_section.dart';
import '../wallet_state.dart';

/// Android `WalletListScreen` 대응 — 체인 선택 + 계정/지갑 선택. 하단 고정 "선택" 버튼.
class WalletListScreen extends StatefulWidget {
  final WalletState wallet;
  final VoidCallback onBack;
  final VoidCallback onWalletSelected;
  const WalletListScreen({
    super.key,
    required this.wallet,
    required this.onBack,
    required this.onWalletSelected,
  });

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> {
  @override
  void initState() {
    super.initState();
    // 빌드 도중 notifyListeners 가 불리지 않도록 다음 프레임에 호출 (Android LaunchedEffect 대응).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final w = widget.wallet;
      if (w.initialized && w.accounts.isEmpty && !w.busy('getAccountList')) {
        w.getAccountList();
      }
    });
  }

  String _short(String s) =>
      s.length <= 16 ? s : '${s.substring(0, 10)}…${s.substring(s.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final hint = Theme.of(context).hintColor;
    final canProceed = wallet.publicKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('지갑 선택'),
            Text('userId: ${wallet.userId.isEmpty ? "(none)" : wallet.userId}',
                style: TextStyle(fontSize: 11, color: hint)),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ChainSection(wallet: wallet),
            AccountSection(wallet: wallet),
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canProceed) ...[
                Text('선택된 지갑: ${_short(wallet.address)}',
                    style: TextStyle(fontSize: 11, color: hint)),
                const SizedBox(height: 6),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: canProceed ? widget.onWalletSelected : null,
                  child: Text(canProceed ? '선택' : '지갑을 먼저 선택하세요'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
