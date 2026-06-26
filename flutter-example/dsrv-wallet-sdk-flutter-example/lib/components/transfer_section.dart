import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account_asset_repository.dart';
import '../ui.dart';
import '../wallet_state.dart';
import 'asset_balance_view.dart';
import 'qr_scanner_sheet.dart';

/// Android `TransferSection.kt` / iOS `TransferSection.swift` 대응 — 전송 원샷 (build → sign → broadcast).
///
/// UX: 자산 드롭다운 (WaaS 자산 목록 — native + 보유 ERC-20) + recipient + amount (decimal filter) +
/// "거래 확인" → AlertDialog 확인 → 실제 전송. 기존 ETH/USDC 하드코딩 + RPC 직접호출(BalanceClient) 대체.
/// 자산 드롭다운 + 잔액 + KRW 는 공용 [AssetBalanceView] 가 담당. 여기선 선택된 자산만 받아 전송에 사용.
class TransferSection extends StatefulWidget {
  final WalletState wallet;
  const TransferSection({super.key, required this.wallet});

  @override
  State<TransferSection> createState() => _TransferSectionState();
}

class _TransferSectionState extends State<TransferSection> {
  final _recipient = TextEditingController();
  final _amount = TextEditingController();

  // 자산 드롭다운 + 잔액 + KRW 는 공용 AssetBalanceView 가 담당. 여기선 선택된 자산만 받아 전송에 사용.
  AssetRow? _selectedAsset;

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

  Future<void> _confirmAndSend({
    required AssetRow asset,
    required String? chainName,
  }) async {
    final defaultHuman = asset.isNative ? '0.001' : '1';
    final effective =
        _amount.text.trim().isEmpty ? defaultHuman : _amount.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: '받는 사람', value: _recipient.text, mono: true),
            _ConfirmRow(label: '금액', value: '$effective ${asset.symbol}'),
            if (asset.contractAddress != null)
              _ConfirmRow(label: '토큰', value: asset.contractAddress!, mono: true),
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
      chainId: asset.chainId,
      recipient: _recipient.text,
      amount: _amount.text,
      contractAddress: asset.contractAddress,
      decimals: asset.decimals,
      symbol: asset.symbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final asset = _selectedAsset;
    ChainInfo? chain;
    if (asset != null) {
      final matched = wallet.chains.where((c) => c.chainId == asset.chainId);
      if (matched.isNotEmpty) chain = matched.first;
    }

    final errorColor = Theme.of(context).colorScheme.error;
    final defaultPlaceholder = (asset?.isNative ?? true) ? '0.001' : '1';
    final symbolLabel = asset?.symbol ?? '토큰';

    return SectionCard(
      '전송',
      subtitle: '체인 ${chain?.name ?? asset?.chainId ?? "없음"} · ${asset?.symbol ?? "자산 없음"}',
      children: [
        AssetBalanceView(
          wallet: wallet,
          onSelected: (a) => setState(() => _selectedAsset = a),
        ),
        Row(
          children: [
            Expanded(child: Field(_recipient, '받는 주소')),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final recipient = await scanRecipient(context);
                if (!mounted || recipient == null) return;
                _recipient.text = recipient;
              },
              child: const Text('QR 스캔'),
            ),
          ],
        ),
        TextField(
          controller: _amount,
          decoration: InputDecoration(
            labelText: '금액 ($symbolLabel, 기본 $defaultPlaceholder)',
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
              wallet.publicKey.isNotEmpty &&
              asset != null &&
              _recipient.text.trim().isNotEmpty &&
              !wallet.busy('transfer'),
          isLoading: wallet.busy('transfer'),
          onPressed: () {
            if (asset == null || _recipient.text.trim().isEmpty) return;
            _confirmAndSend(asset: asset, chainName: chain?.name);
          },
        ),
        if (wallet.transferError != null)
          Text('⚠ ${wallet.transferError}',
              style: TextStyle(fontSize: 12, color: errorColor)),
        // 전송 결과 — txHash (있을 때) + status + batchTxId (있을 때).
        // bundler 경로 (GS_ON) 에선 txHash 가 null 이고 status="SIGNED" + batchTxId 가 채워짐.
        if (wallet.lastTxHash != null ||
            wallet.lastTxStatus != null ||
            wallet.lastBatchTxId != null) ...[
          Text('✓ 전송 결과',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          if (wallet.lastTxHash != null) ...[
            Text('TxHash',
                style: TextStyle(
                    fontSize: 10, color: Theme.of(context).hintColor)),
            CopyableText(wallet.lastTxHash!),
          ],
          if (wallet.lastTxStatus != null)
            Text('Status: ${wallet.lastTxStatus}',
                style: const TextStyle(fontSize: 12)),
          if (wallet.lastBatchTxId != null) ...[
            Text('BatchTxId',
                style: TextStyle(
                    fontSize: 10, color: Theme.of(context).hintColor)),
            CopyableText(wallet.lastBatchTxId!),
          ],
        ],
        if (wallet.transferError != null) ErrorLine(wallet.transferError!),
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
