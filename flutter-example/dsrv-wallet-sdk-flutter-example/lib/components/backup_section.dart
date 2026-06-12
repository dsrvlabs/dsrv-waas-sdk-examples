import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `BackupSection.kt` / iOS `BackupSection.swift` 대응 — 백업 + 디버그 dump/clear.
class BackupSection extends StatelessWidget {
  final WalletState wallet;
  const BackupSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final errorColor = Theme.of(context).colorScheme.error;

    return SectionCard(
      '백업',
      subtitle: 'pending share3 들을 iCloud Keychain / Block Store 에 일괄 sync',
      children: [
        Text(
          'PENDING 상태인 share 를 클라우드에 일괄 sync 합니다. Passkey / 생체인증이 필요할 수 있습니다.',
          style: TextStyle(fontSize: 11, color: hint),
        ),
        AsyncButton(
          title: '백업',
          isEnabled: wallet.initialized,
          isLoading: wallet.busy('backup'),
          onPressed: wallet.backup,
        ),
        if (wallet.backupResult != null)
          Text('✓ ${wallet.backupResult}', style: const TextStyle(fontSize: 12)),
        const Divider(),
        Text('디버그', style: TextStyle(fontSize: 12, color: hint)),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: wallet.busy('dump') ? null : wallet.dumpBackup,
            child: const Text('Block Store / Keychain dump'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: errorColor,
              side: BorderSide(color: errorColor),
            ),
            onPressed: wallet.busy('clearBackup') ? null : wallet.clearBackup,
            child: const Text('Backup 전체 삭제'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed:
                wallet.busy('clearDeviceKey') ? null : wallet.clearDeviceKey,
            child: const Text('Clear Device Key (debug)'),
          ),
        ),
        if (wallet.backupDump != null && wallet.backupDump!.isNotEmpty)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 240),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                wallet.backupDump!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
