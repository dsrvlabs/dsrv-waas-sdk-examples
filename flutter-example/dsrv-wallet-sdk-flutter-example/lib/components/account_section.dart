import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `AccountSection.kt` / iOS `AccountSection.swift` 대응 —
/// account 생성/조회 + 지갑 발급. account 별 ListTile + RadioButton + LabelDialog 패턴.
///
/// Note: Flutter `wallet.createAddress()` 는 selectedAccountId 를 사용 — UI 측에서 account
/// 헤더의 "+ 지갑" 버튼은 해당 accountId 로 selectAccount 후 createAddress 호출.
class AccountSection extends StatelessWidget {
  final WalletState wallet;
  const AccountSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final loading = wallet.busy('getAccountList');

    return SectionCard(
      '계정 & 지갑',
      subtitle: '계정 생성 · 지갑 발급',
      children: [
        Row(
          children: [
            Expanded(
              child: Text('계정 (${wallet.accounts.length})',
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (loading)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton(
                onPressed: wallet.initialized ? wallet.getAccountList : null,
                child: const Text('조회'),
              ),
            TextButton(
              onPressed: (wallet.initialized && !wallet.busy('createAccount'))
                  ? () => _showLabelDialog(
                        context: context,
                        title: '새 계정',
                        onConfirm: (label) => wallet.createAccount(label),
                      )
                  : null,
              child: wallet.busy('createAccount')
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('+ 계정'),
            ),
          ],
        ),
        if (wallet.accounts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              loading ? '불러오는 중…' : '계정 없음 — [+ 계정] 으로 생성',
              style: TextStyle(fontSize: 12, color: hint),
            ),
          )
        else
          for (var i = 0; i < wallet.accounts.length; i++) ...[
            _AccountHeader(
              account: wallet.accounts[i],
              onAddWallet: () {
                wallet.selectAccount(wallet.accounts[i].accountId);
                _showLabelDialog(
                  context: context,
                  title: '새 지갑',
                  onConfirm: (_) => wallet.createAddress(),
                );
              },
            ),
            if (wallet.accounts[i].addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                child: Text('지갑 없음',
                    style: TextStyle(fontSize: 11, color: hint)),
              )
            else
              for (final addr in wallet.accounts[i].addresses)
                _WalletRow(
                  address: addr,
                  selected: addr.address.toLowerCase() ==
                      wallet.address.toLowerCase(),
                  onTap: () {
                    wallet.selectAccount(wallet.accounts[i].accountId);
                    wallet.selectWallet(addr.address);
                  },
                ),
            if (i < wallet.accounts.length - 1) const Divider(height: 1),
          ],
      ],
    );
  }

  Future<void> _showLabelDialog({
    required BuildContext context,
    required String title,
    required void Function(String) onConfirm,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'label 을 입력하세요 (비우면 자동 생성)',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(ctx).hintColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'label',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('생성'),
          ),
        ],
      ),
    );
    if (result != null) onConfirm(result);
  }
}

class _AccountHeader extends StatelessWidget {
  final AccountInfo account;
  final VoidCallback onAddWallet;
  const _AccountHeader({required this.account, required this.onAddWallet});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  'id ${_shortId(account.accountId)} · ${account.addresses.length} wallets',
                  style: TextStyle(fontSize: 11, color: hint),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onAddWallet, child: const Text('+ 지갑')),
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  final AddressInfo address;
  final bool selected;
  final VoidCallback onTap;
  const _WalletRow({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final display = address.address.length <= 16
        ? address.address
        : '${address.address.substring(0, 10)}…${address.address.substring(address.address.length - 6)}';
    final label = address.label;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected ? true : null,
              onChanged: (_) => onTap(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(display,
                      style: const TextStyle(
                          fontSize: 13, fontFamily: 'monospace')),
                  if (label != null && label.isNotEmpty)
                    Text(label,
                        style: TextStyle(fontSize: 11, color: hint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortId(String id) =>
    id.length <= 12 ? id : '${id.substring(0, 8)}…${id.substring(id.length - 4)}';
