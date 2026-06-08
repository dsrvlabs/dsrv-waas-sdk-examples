import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `RestoreSection.kt` / iOS `RestoreSection.swift` 대응 — 클라우드 백업 복원.
class RestoreSection extends StatelessWidget {
  final WalletState wallet;
  const RestoreSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      'Restore',
      subtitle: '클라우드 백업에서 지갑 복원',
      children: [
        AsyncButton(
          title: '복원',
          isEnabled: wallet.initialized,
          isLoading: wallet.busy('restore'),
          onPressed: wallet.restore,
        ),
        if (wallet.restoreResult != null)
          Text('✓ ${wallet.restoreResult}',
              style: const TextStyle(color: Colors.green, fontSize: 12)),
      ],
    );
  }
}
