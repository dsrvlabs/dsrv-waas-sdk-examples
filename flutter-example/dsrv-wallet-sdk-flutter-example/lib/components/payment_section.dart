import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account_asset_repository.dart';
import '../ui.dart';
import '../wallet_state.dart';
import 'qr_scanner_sheet.dart';

/// Android `PaymentSection.kt` / iOS `PaymentSection.swift` 대응 —
/// customer-backend `POST /payments` 호출 (Topup 결제).
///
/// 결제(topup)는 stablecoin Payments 레일이라 **USDC 전용**입니다 (native·기타 토큰은 upstream
/// `CreateQuoteRequest` 가 ERC-20 컨트랙트 주소를 강제 — 미지원). 따라서 토큰은 USDC 로 고정
/// (체인별 컨트랙트 주소 하드코딩), 잔액은 공용 [WalletState.assets] 에서 USDC 를 찾아 표시, KRW 는 price-hub.
/// chainId/token(USDC 주소)은 여기서, paymentType=0/sourceUserId/from 은 `WalletState.pay` 가 채움.
class PaymentSection extends StatefulWidget {
  final WalletState wallet;
  const PaymentSection({super.key, required this.wallet});

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();

  String? _krwText;
  bool _krwLoading = false;

  /// (address, chainId) 변경 시에만 재조회하기 위한 dedup 키.
  String? _lastLoadKey;

  /// 공용 목록(`wallet.assets`)이 갱신되었는지 판별하는 dedup 키 — 변경 시 1회만 KRW 재조회
  /// (iOS `.onChange(of: assets)` 대응).
  String? _lastAssetsKey;

  /// in-flight KRW 조회 가드 — 이전 요청의 늦은 응답이 현재 상태를 덮어쓰지 못하게 한다.
  int _krwGeneration = 0;

  /// 공용 자산 목록에서 USDC 를 찾는다(없으면 null → 잔액 0). 목록 적재는 [WalletState.loadAssets].
  AssetRow? _usdc(String chainId) {
    final usdcAddr = usdcAddress(chainId);
    if (usdcAddr == null) return null;
    final matched = widget.wallet.assets.where(
        (r) => (r.contractAddress ?? '').toLowerCase() == usdcAddr.toLowerCase());
    return matched.isEmpty ? null : matched.first;
  }

  /// 체인별 USDC 컨트랙트 주소 (topup 전용 하드코딩). 미지원 체인은 null.
  static String? usdcAddress(String chainId) {
    switch (chainId) {
      case '11155111':
        return '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238'; // Ethereum Sepolia
      case '84532':
        return '0x036CbD53842c5426634e7929541eC2318f3dCF7e'; // Base Sepolia
      case '1':
        return '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // Ethereum Mainnet
      case '8453':
        return '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'; // Base Mainnet
      default:
        return null;
    }
  }

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

  /// 공용 목록 식별 키 — 자산 id + 잔액을 합쳐 만든다. 잔액만 바뀌어도 KRW 재환산이 트리거된다.
  String _assetsKey(List<AssetRow> rows) =>
      rows.map((r) => '${r.id}:${r.humanizedBalance}').join('|');

  /// 공용 목록 갱신 시 USDC 잔액 기준 KRW 환산 (미보유면 "0" → ₩0).
  Future<void> _refreshKrw() async {
    final gen = ++_krwGeneration;
    final chainId = widget.wallet.selectedChainId ?? '';
    final usdcAddr = usdcAddress(chainId);
    if (!mounted) return;
    setState(() => _krwText = null);
    if (usdcAddr == null) return;
    setState(() => _krwLoading = true);
    // 보유 USDC humanized 잔액 기준 KRW (미보유면 "0" → ₩0).
    final amt = _usdc(chainId)?.humanizedBalance ?? '0';
    final krw = await widget.wallet.getKrwValue(
      chainId: chainId,
      contractAddress: usdcAddr,
      amount: amt,
    );
    if (!mounted || gen != _krwGeneration) return;
    setState(() {
      _krwText = krw;
      _krwLoading = false;
    });
  }

  Future<void> _confirmAndPay({
    required String usdcAddr,
    required String chainId,
    required String? chainName,
  }) async {
    final effectiveAmount = _amountController.text.trim().isEmpty
        ? '1'
        : _amountController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결제 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: '받는 사람', value: _toController.text, mono: true),
            _ConfirmRow(label: '금액', value: '$effectiveAmount USDC'),
            _ConfirmRow(label: '토큰', value: usdcAddr, mono: true),
            if (chainName != null) _ConfirmRow(label: '체인', value: chainName),
            const SizedBox(height: 10),
            Text('⚠ 결제 후 되돌릴 수 없습니다.',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(ctx).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('결제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
    widget.wallet.pay(
      chainId: chainId,
      token: usdcAddr,
      to: _toController.text,
      amount: effectiveAmount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final chainId = wallet.selectedChainId ?? '';
    ChainInfo? chain;
    final matchedChain = wallet.chains.where((c) => c.chainId == chainId);
    if (matchedChain.isNotEmpty) chain = matchedChain.first;
    final usdcAddr = usdcAddress(chainId);
    final balanceDisplay = _usdc(chainId)?.humanizedBalance ?? '0';

    // (address, accountId, chainId) 변경 시 1회만 자산 자동 조회. iOS/Android 와 동일하게 accountId 포함.
    if (wallet.address.isNotEmpty) {
      final key = '${wallet.address}|${wallet.selectedAccountId ?? ''}|$chainId';
      if (key != _lastLoadKey) {
        _lastLoadKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) wallet.loadAssets();
        });
      }
    }

    // 공용 목록 갱신 시 USDC 잔액 기준 KRW 재조회 (iOS .onChange(of: assets)).
    final assetsKey = _assetsKey(wallet.assets);
    if (assetsKey != _lastAssetsKey) {
      _lastAssetsKey = assetsKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshKrw();
      });
    }

    final hint = Theme.of(context).hintColor;
    final errorColor = Theme.of(context).colorScheme.error;
    final chainLabel = chain?.name ?? (chainId.isEmpty ? '없음' : chainId);

    return SectionCard(
      '결제 (Topup)',
      subtitle: '체인 $chainLabel · USDC',
      children: [
        if (usdcAddr != null) ...[
          // 잔액 row + 새로고침
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('USDC 잔액',
                        style: TextStyle(fontSize: 11, color: hint)),
                    if (wallet.assetsLoading)
                      Text('조회 중…', style: TextStyle(fontSize: 11, color: hint))
                    else if (wallet.assetsError != null)
                      Text(wallet.assetsError!,
                          style: TextStyle(fontSize: 11, color: errorColor))
                    else
                      Text('$balanceDisplay USDC',
                          style: const TextStyle(fontSize: 13)),
                    if (_krwLoading)
                      Text('환산 중…', style: TextStyle(fontSize: 11, color: hint))
                    else if (_krwText != null)
                      Text(_krwText!, style: TextStyle(fontSize: 11, color: hint)),
                  ],
                ),
              ),
              TextButton(
                onPressed: wallet.assetsLoading ? null : wallet.loadAssets,
                child: const Text('새로고침'),
              ),
            ],
          ),
          Text(usdcAddr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          Row(
            children: [
              Expanded(child: Field(_toController, 'to (SETTLEMENT 지갑)')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  final to = await scanRecipient(context);
                  if (!mounted || to == null) return;
                  _toController.text = to;
                },
                child: const Text('QR 스캔'),
              ),
            ],
          ),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '금액 (USDC, 기본 1)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
          AsyncButton(
            title: '거래 확인',
            isEnabled: wallet.initialized &&
                wallet.publicKey.isNotEmpty &&
                _toController.text.trim().isNotEmpty &&
                !wallet.busy('pay'),
            isLoading: wallet.busy('pay'),
            onPressed: () {
              if (_toController.text.trim().isEmpty) return;
              _confirmAndPay(
                  usdcAddr: usdcAddr, chainId: chainId, chainName: chain?.name);
            },
          ),
        ] else
          Text('이 체인은 USDC topup 을 지원하지 않습니다',
              style: TextStyle(fontSize: 12, color: errorColor)),
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
  const _ConfirmRow(
      {required this.label, required this.value, this.mono = false});

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
