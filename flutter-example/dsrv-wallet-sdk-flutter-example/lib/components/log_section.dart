import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `LogSection.kt` / iOS `LogSection.swift` 대응 — 최근 작업 로그 + 자동 스크롤.
class LogSection extends StatefulWidget {
  final WalletState wallet;
  const LogSection({super.key, required this.wallet});

  @override
  State<LogSection> createState() => _LogSectionState();
}

class _LogSectionState extends State<LogSection> {
  final _scroll = ScrollController();
  int _lastLogCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그 증가 시 다음 프레임에 끝으로 스크롤 (Android animateScrollTo / iOS ScrollViewReader 대응).
    final count = widget.wallet.logs.length;
    if (count != _lastLogCount) {
      _lastLogCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final logs = wallet.logs;
    final hint = Theme.of(context).hintColor;

    return SectionCard(
      '로그',
      subtitle: 'SDK / backend trace',
      children: [
        Row(
          children: [
            Expanded(
              child: Text('${logs.length} lines',
                  style: TextStyle(fontSize: 12, color: hint)),
            ),
            if (logs.isNotEmpty)
              TextButton(
                onPressed: wallet.clearLogs,
                child: const Text('Clear'),
              ),
          ],
        ),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 240),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            controller: _scroll,
            child: SelectableText(
              logs.isEmpty ? '(no logs)' : logs.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
