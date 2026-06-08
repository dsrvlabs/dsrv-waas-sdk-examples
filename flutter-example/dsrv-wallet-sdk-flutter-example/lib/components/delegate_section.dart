import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `DelegateSection.kt` / iOS `DelegateSection.swift` 대응 — EIP-7702 위임 / 철회.
class DelegateSection extends StatelessWidget {
  final WalletState wallet;
  const DelegateSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      'Delegate',
      subtitle: 'EIP-7702 위임 / 철회',
      children: [
        Row(
          children: [
            Expanded(
              child: AsyncButton(
                title: 'Delegate',
                isEnabled: wallet.initialized && wallet.address.isNotEmpty,
                isLoading: wallet.busy('delegate'),
                onPressed: wallet.delegate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AsyncButton(
                title: 'Revoke',
                isEnabled: wallet.initialized && wallet.address.isNotEmpty,
                isLoading: wallet.busy('revoke'),
                onPressed: wallet.revoke,
              ),
            ),
          ],
        ),
        if (wallet.delegateResults.isNotEmpty) ...[
          const Text('delegate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ChainResultSummary(results: wallet.delegateResults),
          ...wallet.delegateResults.map((r) => ChainResultLine(result: r)),
        ],
        if (wallet.revokeResults.isNotEmpty) ...[
          const Text('revoke', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ChainResultSummary(results: wallet.revokeResults),
          ...wallet.revokeResults.map((r) => ChainResultLine(result: r)),
        ],
      ],
    );
  }
}
