import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../balance_client.dart';
import '../token_config.dart';
import '../ui.dart';
import '../wallet_state.dart';
import 'qr_scanner_sheet.dart';

/// Android `TransferSection.kt` / iOS `TransferSection.swift` 대응 — 전송 원샷 (build → sign → broadcast).
///
/// UX: 토큰 segmented (ETH + ERC-20) + recipient + amount (decimal filter) + "거래 확인" →
/// AlertDialog 확인 → 실제 전송.
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

  final _balanceClient = BalanceClient();

  /// humanized on-chain 잔액 (예: "0.5"). 조회 전이면 null.
  String? _balanceHuman;
  bool _balanceLoading = false;
  String? _balanceError;

  /// 보유분 KRW 환산 (이미 "₩" 포함 포맷 문자열). 잔액 0 또는 조회 실패면 null.
  String? _krwValue;
  bool _krwLoading = false;

  /// (chainId, _selectedToken, address) 변경 시에만 재조회하기 위한 dedup 키.
  String? _lastFetchKey;

  /// in-flight 잔액/KRW 조회 가드 — 체인·토큰·주소가 바뀌면 증가시켜, 이전 요청의 늦은 응답이
  /// 현재 상태를 덮어쓰지 못하게 한다 (iOS `refreshGeneration` 과 동일).
  int _refreshGeneration = 0;

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

  /// on-chain 잔액 조회 — ETH-native(decimals 18, contract null) vs ERC-20 분기.
  /// 잔액 RPC 는 여기서, KRW 환산/포맷은 [WalletState.getKrwValue] 에 위임한다 (Android·iOS 와 동일).
  Future<void> _refreshBalance(String chainId, TokenInfo? tokenInfo) async {
    final address = widget.wallet.address;
    if (address.isEmpty) {
      if (!mounted) return;
      setState(() {
        _balanceHuman = null;
        _balanceError = '체인·지갑 없음';
        _krwValue = null;
      });
      return;
    }
    if (TokenConfig.getRpcUrl(chainId) == null) {
      if (!mounted) return;
      setState(() {
        _balanceHuman = null;
        _balanceError = '이 체인의 RPC 가 등록되지 않았습니다';
        _krwValue = null;
      });
      return;
    }

    final isNative = _selectedToken == 'ETH';
    final decimals = isNative ? 18 : (tokenInfo?.decimals ?? 18);
    final contract = isNative ? null : tokenInfo?.address;
    if (!isNative && contract == null) return;

    // 이 호출의 세대 번호 — await 재개 시점마다 최신 세대와 같은지 확인해 stale 응답을 버린다.
    final gen = ++_refreshGeneration;
    setState(() {
      _balanceLoading = true;
      _balanceError = null;
      _krwValue = null;
      // 이전 조회가 stale 가드로 일찍 반환되며 남겨둔 스피너를 새 조회 시작 시 항상 초기화.
      _krwLoading = false;
    });
    try {
      final base = isNative
          ? await _balanceClient.getNativeBalance(chainId, address)
          : await _balanceClient.getErc20Balance(chainId, contract!, address);
      final human = fromBaseUnits(base, decimals);
      if (!mounted || gen != _refreshGeneration) return;
      setState(() {
        _balanceHuman = human;
        _balanceLoading = false;
        _krwLoading = true;
      });
      // KRW 환산/포맷은 WalletState 에 위임 — 실패해도 null 만 반환하므로 잔액 라인과 독립적.
      final krw = await widget.wallet.getKrwValue(
        chainId: chainId,
        contractAddress: contract,
        amount: human,
      );
      if (!mounted || gen != _refreshGeneration) return;
      setState(() {
        _krwValue = krw;
        _krwLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _refreshGeneration) return;
      setState(() {
        _balanceError = '$e';
        _balanceLoading = false;
      });
    }
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

    // (chainId, token, address) 변경 시 1회만 잔액 자동 조회.
    if (chainId != null && wallet.address.isNotEmpty) {
      final key = '$chainId|$_selectedToken|${wallet.address}';
      if (key != _lastFetchKey) {
        _lastFetchKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshBalance(chainId, tokenInfo);
        });
      }
    }

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
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 잔액', style: TextStyle(fontSize: 11, color: hint)),
                  if (_balanceLoading)
                    Text('잔액 조회 중…', style: TextStyle(fontSize: 11, color: hint))
                  else if (_balanceError != null)
                    Text('잔액 조회 실패: $_balanceError',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.error))
                  else if (_balanceHuman != null)
                    Text('잔액 $_balanceHuman $_selectedToken',
                        style: TextStyle(fontSize: 11, color: hint))
                  else
                    Text('—', style: TextStyle(fontSize: 11, color: hint)),
                  if (_krwLoading)
                    Text('KRW 환산 중…', style: TextStyle(fontSize: 11, color: hint))
                  else if (_krwValue != null)
                    Text(_krwValue!, style: TextStyle(fontSize: 11, color: hint)),
                ],
              ),
            ),
            TextButton(
              onPressed: (_balanceLoading || chainId == null)
                  ? null
                  : () => _refreshBalance(chainId, tokenInfo),
              child: const Text('새로고침'),
            ),
          ],
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
              wallet.publicKey.isNotEmpty &&
              chainId != null &&
              _recipient.text.trim().isNotEmpty &&
              (_selectedToken == 'ETH' || tokenInfo != null) &&
              !wallet.busy('transfer'),
          isLoading: wallet.busy('transfer'),
          onPressed: () {
            if (chainId == null) return;
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
        if (wallet.transferError != null)
          Text('⚠ ${wallet.transferError}',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.error)),
        if (wallet.lastTxHash != null) ...[
          Text('✓ 전송 완료',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          CopyableText(wallet.lastTxHash!),
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
