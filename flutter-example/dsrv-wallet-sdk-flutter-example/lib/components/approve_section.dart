import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `ApproveSection.kt` / iOS `ApproveSection.swift` 대응 — multicall approve.
///
/// 지원 chain 전체 × `project_assets` 의 활성 ERC-20 을 한 번에 approve.
/// client 는 chain / token 을 명시하지 않는다 — WaaS 가 자동 결정.
/// delegate 가 선행되어 있어야 한다.
///
/// amount 는 자유 입력 — 비우면 SDK 가 "MAX" 로 처리. "0" 입력 시 Permit2 권한만 revoke.
class ApproveSection extends StatefulWidget {
  final WalletState wallet;
  const ApproveSection({super.key, required this.wallet});

  @override
  State<ApproveSection> createState() => _ApproveSectionState();
}

class _ApproveSectionState extends State<ApproveSection> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final canAct = wallet.initialized && wallet.publicKey.isNotEmpty;

    return SectionCard(
      'Approve',
      subtitle: '결제 컨트랙트 multicall approve — 모든 chain × 등록 token 일괄',
      children: [
        Text(
          'WaaS 의 project_assets 에 등록된 활성 ERC-20 을 지원 chain 전체에 일괄 approve 합니다. '
          '비워두면 MAX (unbounded). "0" 입력 시 Permit2 권한 해제.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
        Field(_amount, 'amount (기본 MAX)'),
        AsyncButton(
          title: 'Approve',
          isEnabled: canAct,
          isLoading: wallet.busy('approve'),
          onPressed: () => wallet.approve(amount: _amount.text),
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
