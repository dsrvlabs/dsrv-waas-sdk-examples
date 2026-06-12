import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../token_config.dart';
import '../ui.dart';
import '../wallet_state.dart';

/// Android `TransferSection.kt` / iOS `TransferSection.swift` 대응 — 전송 원샷 (build → sign → broadcast).
///
/// UX: 토큰 segmented (ETH + ERC-20) + recipient + amount (decimal filter) + "거래 확인" →
/// AlertDialog 확인 → 실제 전송.
/// Note: QR 스캔과 balance RPC 조회는 별도 라이브러리/RPC 의존 — Flutter 에선 생략.
class TransferSection extends StatefulWidget {
  final WalletState wallet;
  const TransferSection({super.key, required this.wallet});

  @override
  State<TransferSection> createState() => _TransferSectionState();
}

class _TransferSectionState extends State<TransferSection> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  String _selectedToken = 'ETH';

  @override
  void initState() {
    super.initState();
    // TextEditingController 텍스트 변경 시 build 재실행 트리거 — 버튼 isEnabled 가 reactive 하게 됨.
    _recipient.addListener(_onTextChanged);
    _amount.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _recipient.removeListener(_onTextChanged);
    _amount.removeListener(_onTextChanged);
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<String> _availableTokens(String? chainId) =>
      ['ETH', ...(chainId == null ? const <String>[] : TokenConfig.getAvailableTokenSymbols(chainId))];

  void _syncSelected(List<String> tokens) {
    if (!tokens.contains(_selectedToken)) {
      _selectedToken = tokens.first;
    }
  }

  /// humanized amount ("1.5") + decimals → base units 정수 문자열.
  /// 정수 연산만 사용해 부동소수점 오차 방지.
  String _toBaseUnits(String human, int decimals) {
    final s = human.trim();
    if (s.isEmpty) return '0';
    final parts = s.split('.');
    final intPart = parts[0];
    final fracPart = parts.length > 1 ? parts[1] : '';
    final padded = (fracPart.length >= decimals)
        ? fracPart.substring(0, decimals)
        : fracPart.padRight(decimals, '0');
    final combined = (intPart + padded).replaceFirst(RegExp(r'^0+'), '');
    return combined.isEmpty ? '0' : combined;
  }

  Future<void> _confirmAndSend({
    required String chainId,
    required String? contractAddress,
    required String tokenLabel,
    required int decimals,
    required String? chainName,
  }) async {
    final defaultHuman = _selectedToken == 'ETH' ? '0.001' : '1';
    final effective = _amount.text.trim().isEmpty ? defaultHuman : _amount.text.trim();
    final wei = _toBaseUnits(effective, decimals);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: '받는 사람', value: _recipient.text, mono: true),
            _ConfirmRow(label: '금액', value: '$effective $tokenLabel'),
            if (contractAddress != null)
              _ConfirmRow(label: '토큰', value: contractAddress, mono: true),
            if (chainName != null) _ConfirmRow(label: '체인', value: chainName),
            const SizedBox(height: 10),
            Text('⚠ 서명 후 되돌릴 수 없습니다.',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(ctx).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('서명 & 전송')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.wallet.transfer(
      chainId: chainId,
      recipient: _recipient.text,
      amount: wei,
      contractAddress: contractAddress,
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

    final tokens = _availableTokens(chainId);
    _syncSelected(tokens);

    final tokenInfo = (_selectedToken != 'ETH' && chainId != null)
        ? TokenConfig.getToken(chainId, _selectedToken)
        : null;

    final hint = Theme.of(context).hintColor;
    final defaultPlaceholder = _selectedToken == 'ETH' ? '0.001' : '1';

    return SectionCard(
      '전송',
      subtitle: '체인 ${chain?.name ?? "없음"} · $_selectedToken',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              for (final t in tokens) ButtonSegment(value: t, label: Text(t)),
            ],
            selected: {_selectedToken},
            onSelectionChanged: (sel) =>
                setState(() => _selectedToken = sel.first),
          ),
        ),
        if (_selectedToken == 'ETH')
          Text('네이티브 코인 (gas 토큰) · decimals 18',
              style: TextStyle(fontSize: 11, color: hint))
        else if (tokenInfo != null) ...[
          Text('${tokenInfo.name} · decimals ${tokenInfo.decimals}',
              style: TextStyle(fontSize: 11, color: hint)),
          Text(tokenInfo.address,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ] else
          Text('이 체인에 정의된 $_selectedToken 토큰 정보가 없습니다',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
        Field(_recipient, '받는 주소'),
        TextField(
          controller: _amount,
          decoration: InputDecoration(
            labelText: '금액 ($_selectedToken, 기본 $defaultPlaceholder)',
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
              chainId != null &&
              _recipient.text.isNotEmpty &&
              (_selectedToken == 'ETH' || tokenInfo != null),
          isLoading: wallet.busy('transfer'),
          onPressed: () {
            if (chainId == null || _recipient.text.isEmpty) return;
            final decimals = _selectedToken == 'ETH' ? 18 : (tokenInfo?.decimals ?? 18);
            _confirmAndSend(
              chainId: chainId,
              contractAddress: tokenInfo?.address,
              tokenLabel: _selectedToken,
              decimals: decimals,
              chainName: chain?.name,
            );
          },
        ),
        if (wallet.lastTxHash != null) ...[
          Text('✓ 전송 완료',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          CopyableText(wallet.lastTxHash!),
        ],
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
