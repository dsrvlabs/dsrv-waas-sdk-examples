import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `DelegateSection.kt` / iOS `DelegateSection.swift` 대응 — EIP-7702 위임 / 철회.
///
/// UX: 위임 안 된 상태에선 Delegate 만 노출, 위임 완료 후에만 Divider + Revoke 노출 (destructive).
/// 모든 chain 이 ALREADY_DELEGATED 면 "이미 위임됨" 메시지 + "다시 시도" 버튼.
class DelegateSection extends StatelessWidget {
  final WalletState wallet;
  const DelegateSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final results = wallet.delegateResults;
    final alreadyDone = results.isNotEmpty &&
        results.every((r) => r.outcome == 'ALREADY_DELEGATED');
    final delegateDone = results.isNotEmpty;
    final canAct = wallet.initialized && wallet.address.isNotEmpty;

    return SectionCard(
      'Delegate (EIP-7702)',
      subtitle: '지원 chain 일괄 broadcast',
      children: [
        AsyncButton(
          title: alreadyDone ? '다시 시도' : 'Delegate',
          isEnabled: canAct,
          isLoading: wallet.busy('delegate'),
          onPressed: wallet.delegate,
        ),
        if (alreadyDone)
          const Text('✓ 이미 위임됨 — 추가 작업 불필요',
              style: TextStyle(fontSize: 12))
        else if (results.isNotEmpty) ...[
          ChainResultSummary(results: results),
          ...results.map((r) => ChainResultLine(result: r)),
        ],
        if (delegateDone) ...[
          const Divider(),
          const Text('위임 해제 (Revoke)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(
            '지원 chain 의 위임을 해제합니다. 해제 시 페이먼트의 Approve 도 사실상 무효화됩니다.',
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
          ),
          _OutlinedDestructiveButton(
            title: 'Revoke',
            isEnabled: canAct,
            isLoading: wallet.busy('revoke'),
            onPressed: wallet.revoke,
          ),
          if (wallet.revokeResults.isNotEmpty) ...[
            ChainResultSummary(results: wallet.revokeResults),
            ...wallet.revokeResults.map((r) => ChainResultLine(result: r)),
          ],
        ],
      ],
    );
  }
}

/// Android `OutlinedButton(color=error)` / iOS `.destructive` style 의 Flutter 대응.
class _OutlinedDestructiveButton extends StatelessWidget {
  final String title;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;
  const _OutlinedDestructiveButton({
    required this.title,
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: errorColor,
          side: BorderSide(color: errorColor),
        ),
        onPressed: (!isEnabled || isLoading) ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: errorColor),
              )
            : Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
