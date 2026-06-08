import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';

import '../token_config.dart';
import '../ui.dart';
import '../wallet_state.dart';

/// Android `PaymentSection.kt` / iOS `PaymentSection.swift` 대응 —
/// customer-backend `POST /payments` 호출 (Topup 결제).
///
/// 체인 자동(selectedChainId), 토큰은 ERC-20 드롭다운(USDC default). amount 는 사람 읽는 단위
/// (humanized, 예: "1.5") 그대로 입력 — wei 변환은 stablecoin Payments 측이 담당.
class PaymentSection extends StatefulWidget {
  final WalletState wallet;
  const PaymentSection({super.key, required this.wallet});

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  String _selectedSymbol = '';

  List<String> _tokenSymbols(String? chainId) =>
      chainId == null ? const [] : TokenConfig.getAvailableTokenSymbols(chainId);

  void _syncSelected(String? chainId) {
    final symbols = _tokenSymbols(chainId);
    if (symbols.isEmpty) {
      if (_selectedSymbol.isNotEmpty) _selectedSymbol = '';
    } else if (!symbols.contains(_selectedSymbol)) {
      _selectedSymbol = symbols.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final chainId = wallet.selectedChainId;
    ChainInfo? chain;
    if (chainId != null) {
      final matched = wallet.chains.where((c) => c.chainId == chainId);
      if (matched.isNotEmpty) chain = matched.first;
    }
    final tokenSymbols = _tokenSymbols(chainId);
    _syncSelected(chainId);

    final tokenInfo = (chainId != null && _selectedSymbol.isNotEmpty)
        ? TokenConfig.getToken(chainId, _selectedSymbol)
        : null;

    final toController = TextEditingController();
    final amountController = TextEditingController();

    return SectionCard(
      'Payment (Topup)',
      subtitle: chain == null
          ? '지갑 화면에서 체인을 선택하세요'
          : '체인: ${chain.name} · ${chain.chainId}',
      children: [
        if (chainId == null)
          const Text('체인이 선택되지 않았습니다.',
              style: TextStyle(fontSize: 12, color: Colors.red))
        else if (tokenSymbols.isEmpty)
          const Text('이 체인에 정의된 ERC-20 토큰이 없습니다.',
              style: TextStyle(fontSize: 12, color: Colors.red))
        else ...[
          DropdownButtonFormField<String>(
            initialValue: _selectedSymbol.isEmpty ? null : _selectedSymbol,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '토큰',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: tokenSymbols
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedSymbol = v);
            },
          ),
          if (tokenInfo != null)
            Text(
              tokenInfo.address,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
        ],
        Field(toController, 'to (SETTLEMENT 지갑)'),
        Field(amountController, 'amount (예: 1.5)',
            keyboard: const TextInputType.numberWithOptions(decimal: true)),
        AsyncButton(
          title: '결제',
          isEnabled: wallet.initialized &&
              wallet.address.isNotEmpty &&
              tokenInfo != null,
          isLoading: wallet.busy('pay'),
          onPressed: () {
            if (tokenInfo == null) return;
            wallet.pay(
              chainId: chainId ?? '',
              token: tokenInfo.address,
              to: toController.text,
              amount: amountController.text,
            );
          },
        ),
        if (wallet.paymentResult != null) ...[
          Text('✓ status=${wallet.paymentResult!.status}',
              style: const TextStyle(fontSize: 12)),
          const Text('transactionId',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          CopyableText(wallet.paymentResult!.transactionId),
          const Text('paymentUuid',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          CopyableText(wallet.paymentResult!.paymentUuid),
          if (wallet.paymentResult!.txHash?.isNotEmpty ?? false) ...[
            const Text('txHash',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            CopyableText(wallet.paymentResult!.txHash!),
          ],
          if (wallet.paymentResult!.submittedAt != null)
            Text('submittedAt=${wallet.paymentResult!.submittedAt}',
                style: const TextStyle(fontSize: 11)),
        ],
        if (wallet.paymentError != null) ErrorLine(wallet.paymentError!),
      ],
    );
  }
}
