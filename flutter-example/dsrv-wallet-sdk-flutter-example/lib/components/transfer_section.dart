import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet_state.dart';

/// Android `TransferSection.kt` / iOS `TransferSection.swift` 대응 — 전송 원샷 (build → sign → broadcast).
class TransferSection extends StatefulWidget {
  final WalletState wallet;
  const TransferSection({super.key, required this.wallet});

  @override
  State<TransferSection> createState() => _TransferSectionState();
}

class _TransferSectionState extends State<TransferSection> {
  final _chainId = TextEditingController();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _chainId.dispose();
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    return SectionCard(
      'Transfer',
      subtitle: 'build → MPC sign → broadcast 원샷',
      children: [
        Field(_chainId, 'chainId (비우면 선택된 chain)'),
        Field(_recipient, 'recipient (비우면 데모 주소)'),
        Field(_amount, 'amount wei (비우면 0.001 ETH)'),
        AsyncButton(
          title: 'Transfer',
          isEnabled: wallet.initialized && wallet.address.isNotEmpty,
          isLoading: wallet.busy('transfer'),
          onPressed: () => wallet.transfer(
            chainId: _chainId.text,
            recipient: _recipient.text,
            amount: _amount.text,
          ),
        ),
        if (wallet.lastTxHash != null) ...[
          const Text('txHash', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          CopyableText(wallet.lastTxHash!),
        ],
      ],
    );
  }
}
