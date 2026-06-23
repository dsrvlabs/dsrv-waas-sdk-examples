import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `SetupStatusSection.kt` / iOS `SetupStatusSection.swift` 대응 —
/// 선택된 지갑의 chain 별 위임(EIP-7702) / 승인(Permit2) 상태 조회.
///
/// `DSRVWallet.getSetupStatus(accountId, addressId)` 를 호출해 chain 별 delegated +
/// token 별 approved / amount / expiration 을 렌더링한다. 화면 진입·선택 지갑 변경 시 자동 조회되며,
/// delegate / revoke / approve 직후에도 [WalletState] 가 자동 새로고침한다. [새로고침] 버튼으로 수동 갱신도 가능하다.
class SetupStatusSection extends StatefulWidget {
  final WalletState wallet;
  const SetupStatusSection({super.key, required this.wallet});

  @override
  State<SetupStatusSection> createState() => _SetupStatusSectionState();
}

class _SetupStatusSectionState extends State<SetupStatusSection> {
  String? _loadedAddressId;

  WalletState get wallet => widget.wallet;

  @override
  void initState() {
    super.initState();
    _maybeAutoLoad();
  }

  /// 진입·선택 지갑 변경 시 1회 자동 조회 — stale 한 이전 승인 내역이 남지 않도록.
  void _maybeAutoLoad() {
    final addressId = wallet.selectedAddressId;
    if (!wallet.initialized || addressId == null) return;
    if (_loadedAddressId == addressId) return;
    _loadedAddressId = addressId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) wallet.getSetupStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeAutoLoad();
    final hint = Theme.of(context).hintColor;
    final canAct = wallet.initialized && wallet.selectedAddressId != null;
    final loading = wallet.busy('getSetupStatus');
    final statuses = wallet.setupStatus;

    return SectionCard(
      'Setup Status 상태',
      subtitle: 'chain 별 위임 / 승인 현황 (Permit2)',
      children: [
        Text(
          '선택된 지갑의 chain 별 EIP-7702 위임 여부와 결제 컨트랙트 approve 상태를 조회합니다. '
          '진입·지갑 변경 시 및 Delegate / Approve / Revoke 직후 자동 갱신됩니다.',
          style: TextStyle(fontSize: 12, color: hint),
        ),
        AsyncButton(
          title: '새로고침',
          isEnabled: canAct,
          isLoading: loading,
          onPressed: wallet.getSetupStatus,
        ),
        if (wallet.setupStatusError != null)
          ErrorLine(wallet.setupStatusError!),
        if (statuses.isEmpty && !loading && wallet.setupStatusError == null)
          Text('조회된 chain 없음 — [새로고침] 으로 불러오세요.',
              style: TextStyle(fontSize: 12, color: hint))
        else
          for (final status in statuses) _ChainSetupStatusRow(status: status),
      ],
    );
  }
}

class _ChainSetupStatusRow extends StatelessWidget {
  final ChainSetupStatus status;
  const _ChainSetupStatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('chain ${status.chainId}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              _StatusChip(label: '위임', value: status.delegated),
            ],
          ),
          if (status.approvals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('token 없음',
                  style: TextStyle(fontSize: 11, color: hint)),
            )
          else
            for (final t in status.approvals) _TokenApprovalRow(token: t),
        ],
      ),
    );
  }
}

class _TokenApprovalRow extends StatelessWidget {
  final TokenApproval token;
  const _TokenApprovalRow({required this.token});

  String _shortAddr(String a) => a.length <= 14
      ? a
      : '${a.substring(0, 8)}…${a.substring(a.length - 4)}';

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(token.approved ? '✓ ' : '✗ ',
                  style: TextStyle(
                      fontSize: 12,
                      color: token.approved
                          ? Colors.green
                          : Theme.of(context).colorScheme.error)),
              Expanded(
                child: Text(_shortAddr(token.token),
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace')),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'amount=${token.amount} · exp=${token.expiration} · erc20Allowance=${token.erc20Allowance}',
              style: TextStyle(fontSize: 10, color: hint),
            ),
          ),
        ],
      ),
    );
  }
}

/// 위임/승인 여부 표시 칩 — true=초록, false=빨강, null=회색(미산정).
class _StatusChip extends StatelessWidget {
  final String label;
  final bool? value;
  const _StatusChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (value) {
      true => Colors.green,
      false => Theme.of(context).colorScheme.error,
      null => Theme.of(context).hintColor,
    };
    final String mark = switch (value) {
      true => '✓',
      false => '✗',
      null => '—',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $mark',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
