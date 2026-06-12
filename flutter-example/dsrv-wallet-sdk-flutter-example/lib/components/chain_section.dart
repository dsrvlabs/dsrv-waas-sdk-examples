import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `ChainSection.kt` / iOS `ChainSection.swift` 대응 — 지원 체인 조회 + 단일 선택 list.
class ChainSection extends StatelessWidget {
  final WalletState wallet;
  const ChainSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final loading = wallet.busy('getChainList');

    return SectionCard(
      '체인',
      subtitle: '지원 체인 · 활성 선택',
      children: [
        Row(
          children: [
            Expanded(
              child: Text('목록 (${wallet.chains.length})',
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: wallet.initialized ? wallet.getChainList : null,
                child: const Text('조회'),
              ),
          ],
        ),
        for (var i = 0; i < wallet.chains.length; i++) ...[
          _ChainRow(
            name: wallet.chains[i].name,
            chainType: wallet.chains[i].chainType,
            networkType: wallet.chains[i].networkType,
            chainId: wallet.chains[i].chainId,
            selected: wallet.chains[i].chainId == wallet.selectedChainId,
            onTap: () => wallet.selectChain(wallet.chains[i].chainId),
          ),
          if (i < wallet.chains.length - 1) const Divider(height: 1),
        ],
        if (wallet.chains.isEmpty && !loading)
          Text('체인 목록이 비어있습니다.',
              style: TextStyle(fontSize: 12, color: hint)),
      ],
    );
  }
}

class _ChainRow extends StatelessWidget {
  final String name;
  final String chainType;
  final String networkType;
  final String chainId;
  final bool selected;
  final VoidCallback onTap;
  const _ChainRow({
    required this.name,
    required this.chainType,
    required this.networkType,
    required this.chainId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
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
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Text('$chainType·$networkType·$chainId',
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
