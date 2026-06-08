import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `ChainSection.kt` / iOS `ChainSection.swift` 대응 — 지원 체인 조회 + 선택.
class ChainSection extends StatelessWidget {
  final WalletState wallet;
  const ChainSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      'Chain',
      subtitle: '지원 체인 조회 / 선택',
      children: [
        AsyncButton(
          title: '체인 목록',
          isEnabled: wallet.initialized,
          isLoading: wallet.busy('getChainList'),
          onPressed: wallet.getChainList,
        ),
        if (wallet.chains.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: wallet.chains.map((c) {
              final sel = c.chainId == wallet.selectedChainId;
              final accent = Theme.of(context).colorScheme.primary;
              return GestureDetector(
                onTap: () => wallet.selectChain(c.chainId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? accent : accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${c.name} (${c.chainId})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? Colors.white : accent,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
