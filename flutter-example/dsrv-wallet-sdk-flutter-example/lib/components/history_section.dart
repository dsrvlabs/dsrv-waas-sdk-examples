import 'package:flutter/material.dart';

import '../transaction_history_repository.dart';
import '../ui.dart';
import '../wallet_state.dart';

/// 거래 내역 조회 — customer-backend `GET /sdk/transactions` (선택 지갑 fromAddress 기준).
/// Android `HistorySection.kt` / iOS `HistorySection.swift` 대응.
class HistorySection extends StatefulWidget {
  final WalletState wallet;
  const HistorySection({super.key, required this.wallet});

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  @override
  void initState() {
    super.initState();
    // 진입 시 자동 조회
    if (widget.wallet.address.isNotEmpty) {
      widget.wallet.getTransactionHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final loading = wallet.busy('history');

    return SectionCard(
      '거래 내역',
      subtitle: '총 ${wallet.historyTotal}건 · 지갑 ${_shortHex(wallet.address)}',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            TextButton(
              onPressed: (!wallet.initialized || loading)
                  ? null
                  : () => wallet.getTransactionHistory(),
              child: const Text('새로고침'),
            ),
          ],
        ),
        if (wallet.historyError != null) ErrorLine(wallet.historyError!),
        if (wallet.historyItems.isEmpty &&
            !loading &&
            wallet.historyError == null)
          Text('거래 내역이 없습니다.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        for (final item in wallet.historyItems) _HistoryItemCard(item: item),
        if (wallet.historyItems.length < wallet.historyTotal)
          OutlinedButton(
            onPressed: loading
                ? null
                : () => wallet.getTransactionHistory(loadMore: true),
            child: Text(
                '더 보기 (${wallet.historyItems.length}/${wallet.historyTotal})'),
          ),
      ],
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final TransactionHistoryItem item;
  const _HistoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.method ?? 'transaction',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(item.createdAt,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(item.status, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const Divider(height: 16),
          KeyValueRow('체인', '${item.chainId} (${item.chainType})'),
          KeyValueRow('보낸 주소', _shortHex(item.fromAddress)),
          if (item.toAddress != null) KeyValueRow('받는 주소', _shortHex(item.toAddress!)),
          KeyValueRow('txId', item.transactionId),
          if (item.txHash != null) ...[
            const SizedBox(height: 4),
            Text('txHash',
                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            CopyableText(item.txHash!),
          ],
        ],
      ),
    );
  }
}

String _shortHex(String s) =>
    s.length <= 16 ? s : '${s.substring(0, 10)}…${s.substring(s.length - 4)}';
