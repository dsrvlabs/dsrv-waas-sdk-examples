import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `BackupSection.kt` / iOS `BackupSection.swift` 대응 — 백업 + 디버그 dump/clear.
class BackupSection extends StatelessWidget {
  final WalletState wallet;
  const BackupSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      'Backup',
      subtitle: 'pending share3 들을 iCloud Keychain / Block Store 에 일괄 sync',
      children: [
        AsyncButton(
          title: '백업',
          isEnabled: wallet.initialized,
          isLoading: wallet.busy('backup'),
          onPressed: wallet.backup,
        ),
        if (wallet.backupResult != null)
          Text('✓ ${wallet.backupResult}',
              style: const TextStyle(color: Colors.green, fontSize: 12)),
        const Divider(),
        const Text('디버그',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: wallet.busy('dump') ? null : wallet.dumpBackup,
                  child: const Text('Dump', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: wallet.busy('clearBackup') ? null : wallet.clearBackup,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('전체 삭제', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 36,
          child: OutlinedButton(
            onPressed:
                wallet.busy('clearDeviceKey') ? null : wallet.clearDeviceKey,
            child: const Text('Clear Device Key (debug)',
                style: TextStyle(fontSize: 12)),
          ),
        ),
        if (wallet.backupDump != null && wallet.backupDump!.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: SelectableText(
                wallet.backupDump!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
