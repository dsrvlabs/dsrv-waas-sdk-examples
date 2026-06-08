import 'package:flutter/material.dart';

import '../components/approve_section.dart';
import '../components/backup_section.dart';
import '../components/delegate_section.dart';
import '../components/history_section.dart';
import '../components/log_section.dart';
import '../components/payment_section.dart';
import '../components/restore_section.dart';
import '../components/transfer_section.dart';
import '../ui.dart';
import '../wallet_state.dart';

/// Android `AppScreen.Feature` 대응 — 지갑 상세에서 진입하는 기능별 화면.
enum FeatureKind { query, smartAccount, backup, transfer, history, payment, log }

extension FeatureKindTitle on FeatureKind {
  String get title => switch (this) {
        FeatureKind.query => '지갑 조회',
        FeatureKind.smartAccount => '스마트어카운트',
        FeatureKind.backup => '백업 / 복원',
        FeatureKind.transfer => '전송',
        FeatureKind.history => '거래 내역',
        FeatureKind.payment => '결제',
        FeatureKind.log => '로그',
      };
}

/// Android `FeatureScreen` 대응 — feature 별 바디 라우팅.
class FeatureScreen extends StatelessWidget {
  final WalletState wallet;
  final FeatureKind feature;
  final VoidCallback onBack;
  const FeatureScreen({
    super.key,
    required this.wallet,
    required this.feature,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(feature.title),
      ),
      body: SafeArea(
        child: feature == FeatureKind.log
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: LogSection(wallet: wallet),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._body(context),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    switch (feature) {
      case FeatureKind.query:
        return [_QueryFeature(wallet: wallet)];
      case FeatureKind.smartAccount:
        return [
          DelegateSection(wallet: wallet),
          ApproveSection(wallet: wallet),
        ];
      case FeatureKind.backup:
        return [
          BackupSection(wallet: wallet),
          RestoreSection(wallet: wallet),
        ];
      case FeatureKind.transfer:
        if (wallet.publicKey.isEmpty) {
          return [_infoBanner(context, '지갑을 먼저 선택하세요.')];
        }
        return [TransferSection(wallet: wallet)];
      case FeatureKind.history:
        if (wallet.publicKey.isEmpty) {
          return [_infoBanner(context, '지갑을 먼저 선택하세요.')];
        }
        return [HistorySection(wallet: wallet)];
      case FeatureKind.payment:
        if (wallet.publicKey.isEmpty) {
          return [_infoBanner(context, '지갑을 먼저 선택하세요.')];
        }
        return [PaymentSection(wallet: wallet)];
      case FeatureKind.log:
        return const [];
    }
  }

  Widget _infoBanner(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}

/// 지갑 조회 — Public Key / Address / Chain 정보 + 주소 복사 + 계정 새로고침.
class _QueryFeature extends StatelessWidget {
  final WalletState wallet;
  const _QueryFeature({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final chain =
        wallet.chains.where((c) => c.chainId == wallet.selectedChainId);
    final chainText = chain.isEmpty
        ? '(미선택)'
        : '${chain.first.name} (${chain.first.chainId})';

    return SectionCard(
      '주소 정보',
      children: [
        KeyValueRow('Public Key', wallet.publicKey),
        KeyValueRow('Address', wallet.address),
        KeyValueRow('Chain', chainText),
        if (chain.isNotEmpty)
          KeyValueRow('Type',
              '${chain.first.chainType} / ${chain.first.networkType}'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: wallet.address.isEmpty ? null : wallet.getAccountList,
                child: const Text('계정 새로고침'),
              ),
            ),
          ],
        ),
        if (wallet.address.isNotEmpty) CopyableText(wallet.address),
      ],
    );
  }
}
