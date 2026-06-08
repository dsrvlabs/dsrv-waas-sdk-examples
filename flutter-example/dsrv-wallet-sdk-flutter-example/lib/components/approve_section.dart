import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `ApproveSection.kt` / iOS `ApproveSection.swift` 대응 — multicall MAX approve.
///
/// 지원 chain 전체 × `project_assets` 의 활성 ERC-20 을 한 번에 approve.
/// client 는 chain / token 을 명시하지 않는다 — WaaS 가 자동 결정.
/// delegate 가 선행되어 있어야 한다.
class ApproveSection extends StatelessWidget {
  final WalletState wallet;
  const ApproveSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      'Approve',
      subtitle: '결제 컨트랙트 multicall approve (MAX) — 모든 chain × 등록 token 일괄',
      children: [
        Text(
          'WaaS 의 project_assets 에 등록된 활성 ERC-20 을 지원 chain 전체에 일괄 approve 합니다.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
        AsyncButton(
          title: 'Approve',
          isEnabled: wallet.initialized && wallet.publicKey.isNotEmpty,
          isLoading: wallet.busy('approve'),
          onPressed: () => wallet.approve(),
        ),
        if (wallet.approveResults.isNotEmpty) ...[
          ChainResultSummary(results: wallet.approveResults),
          ...wallet.approveResults.map((r) => ChainResultLine(result: r)),
        ],
        if (wallet.approveError != null) ErrorLine(wallet.approveError!),
      ],
    );
  }
}
