import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `AccountSection.kt` / iOS `AccountSection.swift` 대응 —
/// account 생성/조회 + 선택, MPC 키 create.
class AccountSection extends StatefulWidget {
  final WalletState wallet;
  const AccountSection({super.key, required this.wallet});

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    return SectionCard(
      'Account',
      subtitle: 'account 생성/조회 + MPC 키 create',
      children: [
        Field(_label, 'label (비우면 자동)'),
        Row(
          children: [
            Expanded(
              child: AsyncButton(
                title: 'Create Account',
                isEnabled: wallet.initialized,
                isLoading: wallet.busy('createAccount'),
                onPressed: () => wallet.createAccount(_label.text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AsyncButton(
                title: 'List',
                isEnabled: wallet.initialized,
                isLoading: wallet.busy('getAccountList'),
                onPressed: wallet.getAccountList,
              ),
            ),
          ],
        ),
        if (wallet.accounts.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: wallet.accounts.map((a) {
              final selected = a.accountId == wallet.selectedAccountId;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GestureDetector(
                  onTap: () => wallet.selectAccount(a.accountId),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${a.label} — ${a.accountId}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ...a.addresses.map((w) {
                        final addrSel = w.address == wallet.address;
                        return GestureDetector(
                          onTap: () => wallet.selectWallet(w.address),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '  ${addrSel ? "▶ " : "  "}${w.address}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: addrSel
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        AsyncButton(
          title: 'Create Wallet (MPC 키 생성)',
          isEnabled: wallet.initialized && wallet.selectedAccountId != null,
          isLoading: wallet.busy('createAddress'),
          onPressed: wallet.createAddress,
        ),
        if (wallet.address.isNotEmpty) ...[
          const Text('Current address', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          CopyableText(wallet.address),
        ],
      ],
    );
  }
}
