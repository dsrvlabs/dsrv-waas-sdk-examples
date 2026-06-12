import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../token_config.dart';
import '../ui.dart';
import '../wallet_state.dart';

/// Android `PaymentSection.kt` / iOS `PaymentSection.swift` 대응 —
/// customer-backend `POST /payments` 호출 (Topup 결제).
///
/// 체인 자동(selectedChainId), 토큰은 ERC-20 segmented row (USDC 등). amount 는 사람 읽는 단위
/// (humanized, 예: "1.5") 그대로 입력 — wei 변환은 stablecoin Payments 측이 담당.
/// 결제 버튼 → AlertDialog 확인 → 실제 결제.
class PaymentSection extends StatefulWidget {
  final WalletState wallet;
  const PaymentSection({super.key, required this.wallet});

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedSymbol = '';

  @override
  void initState() {
    super.initState();
    // 텍스트 변경 시 build 재실행 트리거 — '거래 확인' 버튼 isEnabled reactive.
    _toController.addListener(_onTextChanged);
    _amountController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _toController.removeListener(_onTextChanged);
    _amountController.removeListener(_onTextChanged);
    _toController.dispose();
    _amountController.dispose();
    super.dispose();
  }

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

  Future<void> _confirmAndPay({
    required String chainId,
    required dynamic tokenInfo,
    required String? chainName,
  }) async {
    final effectiveAmount =
        _amountController.text.trim().isEmpty ? '1' : _amountController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결제 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: '받는 사람', value: _toController.text, mono: true),
            _ConfirmRow(label: '금액', value: '$effectiveAmount $_selectedSymbol'),
            _ConfirmRow(label: '토큰', value: tokenInfo.address as String, mono: true),
            if (chainName != null) _ConfirmRow(label: '체인', value: chainName),
            const SizedBox(height: 10),
            Text('⚠ 결제 후 되돌릴 수 없습니다.',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(ctx).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('결제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.wallet.pay(
      chainId: chainId,
      token: tokenInfo.address as String,
      to: _toController.text,
      amount: effectiveAmount,
    );
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

    final hint = Theme.of(context).hintColor;
    final errorColor = Theme.of(context).colorScheme.error;

    return SectionCard(
      '결제 (Topup)',
      subtitle: '체인 ${chain?.name ?? "없음"} · ${_selectedSymbol.isEmpty ? "토큰 없음" : _selectedSymbol}',
      children: [
        if (chainId == null)
          Text('체인이 선택되지 않았습니다.',
              style: TextStyle(fontSize: 12, color: errorColor))
        else if (tokenSymbols.isEmpty)
          Text('이 체인에 정의된 ERC-20 토큰이 없습니다 (TokenConfig 확인)',
              style: TextStyle(fontSize: 12, color: errorColor))
        else ...[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: [
                for (final s in tokenSymbols)
                  ButtonSegment(value: s, label: Text(s)),
              ],
              selected: {_selectedSymbol.isEmpty ? tokenSymbols.first : _selectedSymbol},
              onSelectionChanged: (sel) =>
                  setState(() => _selectedSymbol = sel.first),
            ),
          ),
          if (tokenInfo != null) ...[
            Text('${tokenInfo.name} · decimals ${tokenInfo.decimals}',
                style: TextStyle(fontSize: 11, color: hint)),
            Text(tokenInfo.address,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ],
        ],
        Field(_toController, 'to (SETTLEMENT 지갑)'),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'amount (${_selectedSymbol.isEmpty ? "토큰" : _selectedSymbol}, 기본 1)',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        AsyncButton(
          title: '거래 확인',
          isEnabled: wallet.initialized &&
              wallet.address.isNotEmpty &&
              tokenInfo != null &&
              _toController.text.isNotEmpty,
          isLoading: wallet.busy('pay'),
          onPressed: () {
            if (tokenInfo == null || _toController.text.isEmpty) return;
            _confirmAndPay(
              chainId: chainId ?? '',
              tokenInfo: tokenInfo,
              chainName: chain?.name,
            );
          },
        ),
        if (wallet.paymentResult != null) ...[
          Text('✓ status=${wallet.paymentResult!.status}',
              style: const TextStyle(fontSize: 12)),
          Text('transactionId', style: TextStyle(fontSize: 11, color: hint)),
          CopyableText(wallet.paymentResult!.transactionId),
          Text('paymentUuid', style: TextStyle(fontSize: 11, color: hint)),
          CopyableText(wallet.paymentResult!.paymentUuid),
          if (wallet.paymentResult!.txHash?.isNotEmpty ?? false) ...[
            Text('txHash', style: TextStyle(fontSize: 11, color: hint)),
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

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _ConfirmRow({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 11, color: hint)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
