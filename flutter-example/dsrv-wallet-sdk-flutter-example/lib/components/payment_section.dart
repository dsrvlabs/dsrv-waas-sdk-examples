import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account_asset_repository.dart';
import '../ui.dart';
import '../wallet_state.dart';
import 'qr_scanner_sheet.dart';

/// Android `PaymentSection.kt` / iOS `PaymentSection.swift` 대응 —
/// customer-backend `POST /payments` 호출 (cross-chain Topup, DNT-5965/5997).
///
/// source(출금) / destination(수령) 의 chain·token·주소를 직접 입력할 수 있다. 비우면 기본값으로
/// 폴백(source chain=선택 체인, fromAddress=내 지갑, fromTokenAddress=체인 USDC, destination=source 와 동일).
/// USDC 잔액/KRW 행은 선택 체인 기준 참고용 표시이며, 실제 결제 토큰은 fromTokenAddress 입력이 결정한다.
/// paymentType=0/sourceUserId 는 `WalletState.pay` 가 채움.
class PaymentSection extends StatefulWidget {
  final WalletState wallet;
  const PaymentSection({super.key, required this.wallet});

  @override
  State<PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends State<PaymentSection> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  // source(출금) / destination(수령) 입력 — 비우면 기본값 폴백(hint 로 기본값 노출).
  final _sourceChainController = TextEditingController();
  final _fromAddressController = TextEditingController();
  final _fromTokenController = TextEditingController();
  final _destChainController = TextEditingController();
  final _destTokenController = TextEditingController();

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
    // 텍스트 변경 시 build 재실행 트리거 — '거래 확인' 버튼 isEnabled / hint 기본값 reactive.
    _toController.addListener(_onTextChanged);
    _amountController.addListener(_onTextChanged);
    _sourceChainController.addListener(_onTextChanged);
    _fromAddressController.addListener(_onTextChanged);
    _fromTokenController.addListener(_onTextChanged);
    _destChainController.addListener(_onTextChanged);
    _destTokenController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _toController.removeListener(_onTextChanged);
    _amountController.removeListener(_onTextChanged);
    _sourceChainController.removeListener(_onTextChanged);
    _fromAddressController.removeListener(_onTextChanged);
    _fromTokenController.removeListener(_onTextChanged);
    _destChainController.removeListener(_onTextChanged);
    _destTokenController.removeListener(_onTextChanged);
    _toController.dispose();
    _amountController.dispose();
    _sourceChainController.dispose();
    _fromAddressController.dispose();
    _fromTokenController.dispose();
    _destChainController.dispose();
    _destTokenController.dispose();
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
    required String resolvedSourceChain,
    required String resolvedFromAddress,
    required String resolvedFromToken,
  }) async {
    final effectiveAmount = _amountController.text.trim().isEmpty
        ? '1'
        : _amountController.text.trim();
    // destination chain/token 비우면 source 와 동일하게 표시.
    final destChainDisplay = _destChainController.text.isEmpty
        ? resolvedSourceChain
        : _destChainController.text;
    final destTokenDisplay = _destTokenController.text.isEmpty
        ? resolvedFromToken
        : _destTokenController.text;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결제 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: '금액', value: effectiveAmount),
            const SizedBox(height: 6),
            _ConfirmRow(label: 'source chain', value: resolvedSourceChain),
            _ConfirmRow(label: 'from', value: resolvedFromAddress, mono: true),
            _ConfirmRow(label: 'source token', value: resolvedFromToken, mono: true),
            const SizedBox(height: 6),
            _ConfirmRow(label: 'dest chain', value: destChainDisplay),
            _ConfirmRow(label: 'to', value: _toController.text, mono: true),
            _ConfirmRow(label: 'dest token', value: destTokenDisplay, mono: true),
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
    // 빈 입력은 wallet.pay / resolved* 기본값으로 폴백.
    widget.wallet.pay(
      sourceChainId: _sourceChainController.text,
      sourceToken: resolvedFromToken,
      from: _fromAddressController.text,
      destChainId: _destChainController.text,
      destToken: _destTokenController.text,
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

    // 입력값이 비면 사용할 기본값 (= 기존 자동 도출 동작). hint 와 확정 전송에 함께 쓴다.
    final resolvedSourceChain =
        _sourceChainController.text.isEmpty ? chainId : _sourceChainController.text;
    final resolvedFromAddress =
        _fromAddressController.text.isEmpty ? wallet.address : _fromAddressController.text;
    final resolvedFromToken = _fromTokenController.text.isEmpty
        ? (usdcAddress(resolvedSourceChain) ?? '')
        : _fromTokenController.text;
    final headerStyle =
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: hint);

    // DropdownButton.value 는 items 에 존재해야 함(없으면 assertion 크래시). 목록에 없으면 null/'' 로 폴백.
    final chainIds = wallet.chains.map((c) => c.chainId).toSet();
    final safeSourceChain =
        chainIds.contains(resolvedSourceChain) ? resolvedSourceChain : null;
    final safeDestChain = chainIds.contains(_destChainController.text)
        ? _destChainController.text
        : ''; // '' = "source 와 동일"

    return SectionCard(
      '결제 (Topup)',
      subtitle: 'source → destination · 체인 $chainLabel',
      children: [
        // 잔액 helper (참고용) — 선택 체인의 USDC 잔액/KRW. 결제 토큰은 fromTokenAddress 입력이 결정.
        if (usdcAddr != null)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('USDC 잔액 (선택 체인, 참고용)',
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
        // ── source (출금) ── chain 은 가져온 목록에서 선택, 나머지는 비우면 hint 의 기본값.
        Text('source (출금)', style: headerStyle),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'chain',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: safeSourceChain,
              items: [
                for (final c in wallet.chains)
                  DropdownMenuItem(
                      value: c.chainId, child: Text('${c.name} (${c.chainId})')),
              ],
              onChanged: (sel) {
                if (sel == null) return;
                _sourceChainController.text = sel;
              },
            ),
          ),
        ),
        Field(
          _fromAddressController,
          wallet.address.isEmpty ? 'fromAddress (0x…)' : 'fromAddress (기본: 내 지갑)',
        ),
        Field(
          _fromTokenController,
          'fromTokenAddress (기본: ${usdcAddress(resolvedSourceChain) ?? "0x…"})',
        ),
        // ── destination (수령) ── chain/token 비우면 source 와 동일.
        Text('destination (수령)', style: headerStyle),
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
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'chain',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: safeDestChain,
              items: [
                const DropdownMenuItem(value: '', child: Text('source 와 동일')),
                for (final c in wallet.chains)
                  DropdownMenuItem(
                      value: c.chainId, child: Text('${c.name} (${c.chainId})')),
              ],
              onChanged: (sel) {
                if (sel == null) return;
                _destChainController.text = sel;
              },
            ),
          ),
        ),
        Field(_destTokenController, 'tokenAddress (비우면 source 와 동일)'),
        // ── 금액 ── destination 과 구분되는 별도 그룹.
        Text('금액', style: headerStyle),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: '금액 (기본 1)',
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
              resolvedSourceChain: resolvedSourceChain,
              resolvedFromAddress: resolvedFromAddress,
              resolvedFromToken: resolvedFromToken,
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
