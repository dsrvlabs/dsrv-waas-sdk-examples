import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `LogSection.kt` / iOS `LogSection.swift` 대응 — 최근 작업 로그 표시 + 클리어.
class LogSection extends StatelessWidget {
  final WalletState wallet;
  const LogSection({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      'Logs',
      subtitle: '${wallet.logs.length} entries',
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: wallet.logs.isEmpty ? null : wallet.clearLogs,
            child: const Text('Clear'),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: SelectableText(
              wallet.logs.isEmpty ? '(empty)' : wallet.logs.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
