import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wallet_state.dart';
import 'feature_screen.dart';

/// Android `WalletDetailScreen` 대응 — 선택된 지갑 요약 카드 + 기능 메뉴(6개).
class WalletDetailScreen extends StatelessWidget {
  final WalletState wallet;
  final VoidCallback onBack;
  final void Function(FeatureKind) onFeature;
  const WalletDetailScreen({
    super.key,
    required this.wallet,
    required this.onBack,
    required this.onFeature,
  });

  String _short(String s) =>
      s.length <= 16 ? s : '${s.substring(0, 10)}…${s.substring(s.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('지갑 상세'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(context),
            const SizedBox(height: 16),
            Text('기능 테스트', style: TextStyle(fontSize: 12, color: hint)),
            const SizedBox(height: 8),
            _featureMenu(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final account =
        wallet.accounts.where((a) => a.accountId == wallet.selectedAccountId);
    final accountLabel = account.isEmpty ? '(계정 없음)' : account.first.label;
    final accountId = account.isEmpty ? null : account.first.accountId;
    final chain =
        wallet.chains.where((c) => c.chainId == wallet.selectedChainId);
    final chainName = chain.isEmpty ? null : chain.first.name;
    final address = wallet.address;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(accountLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(accountId != null ? 'id ${_short(accountId)}' : '계정 미선택',
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              if (chainName != null)
                Chip(
                  label: Text(chainName, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('지갑 주소',
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          SelectableText(address.isEmpty ? '(지갑 미발급)' : address,
              style: const TextStyle(fontSize: 13)),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('주소 복사'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: address));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('복사됨'),
                      duration: Duration(seconds: 1)));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _featureMenu(BuildContext context) {
    final items = <_FeatureItem>[
      _FeatureItem(FeatureKind.query, Icons.account_balance_wallet_outlined,
          '지갑 조회', '지갑 주소·체인 정보'),
      _FeatureItem(FeatureKind.smartAccount, Icons.verified_user_outlined,
          '스마트어카운트', '위임(EIP-7702) · 승인'),
      _FeatureItem(FeatureKind.backup, Icons.backup_outlined, '백업 / 복원',
          '백업 · 복원 · 키 갱신'),
      _FeatureItem(FeatureKind.transfer, Icons.send_outlined, '전송',
          'ETH · ERC-20 전송'),
      _FeatureItem(FeatureKind.history, Icons.history_outlined, '거래 내역',
          '거래 내역 조회'),
      _FeatureItem(FeatureKind.payment, Icons.payments_outlined, '결제',
          'Topup 결제'),
      _FeatureItem(FeatureKind.log, Icons.article_outlined, '로그',
          'SDK · backend trace'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              leading: Icon(items[i].icon),
              title: Text(items[i].title),
              subtitle: Text(items[i].description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onFeature(items[i].kind),
            ),
            if (i < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _FeatureItem {
  final FeatureKind kind;
  final IconData icon;
  final String title;
  final String description;
  _FeatureItem(this.kind, this.icon, this.title, this.description);
}
