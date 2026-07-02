import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `RestoreSection.kt` / iOS `RestoreSection.swift` 대응 — 클라우드 백업에서 키 share 복원.
class RestoreSection extends StatelessWidget {
  final WalletState wallet;
  const RestoreSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      '복원',
      subtitle: 'Google Drive / iCloud Keychain 에서 키 share 복원',
      children: [
        Text(
          '클라우드에 보관된 share 를 일괄 복원합니다. Passkey / 생체인증이 필요할 수 있습니다.',
          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
        ),
        AsyncButton(
          title: '복원',
          isEnabled: wallet.initialized,
          isLoading: wallet.busy('restore'),
          onPressed: wallet.restore,
        ),
        if (wallet.restoreResult != null)
          Text('✓ ${wallet.restoreResult}', style: const TextStyle(fontSize: 12)),
        // address 별 복원 결과를 화면에 직접 표시 (성공 / 실패)
        ...wallet.restoreResults.map((r) {
          final short =
              r.address.length >= 12 ? '${r.address.substring(0, 12)}…' : r.address;
          return Text(
            r.success
                ? '✓ $short  복원 완료'
                : '⛔ $short  복원 실패${r.error != null ? ' — ${r.error}' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: r.success
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          );
        }),
        if (wallet.restoreError != null)
          Text(
            '⚠ ${wallet.restoreError}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}
