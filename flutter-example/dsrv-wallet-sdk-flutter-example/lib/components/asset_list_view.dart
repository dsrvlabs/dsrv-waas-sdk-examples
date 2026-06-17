import 'package:flutter/material.dart';

import '../account_asset_repository.dart';
import '../ui.dart';
import '../wallet_state.dart';

/// iOS `AssetListView.swift` 대응 — 보유 자산 '전체'를 리스트로 펼쳐 조회.
/// 선택 체인의 모든 자산을 한 번에 표시(자산별 잔액 + KRW).
///
/// 전송 화면의 드롭다운([AssetBalanceView], 선택 1건)과 달리, 여기선 전 자산을 한눈에 본다.
/// 자산 목록/로딩/에러는 [WalletState](공용)에서 관찰하고([WalletState.loadAssets]가 적재),
/// 자산별 KRW 맵만 View 가 보관한다(price-hub [WalletState.getKrwValue], 잔액은 즉시·KRW 는 비동기).
class AssetListView extends StatefulWidget {
  final WalletState wallet;
  const AssetListView({required this.wallet, super.key});

  @override
  State<AssetListView> createState() => _AssetListViewState();
}

class _AssetListViewState extends State<AssetListView> {
  /// 자산별 KRW 환산 문자열 (AssetRow.id → "₩..."). 자산별로 resolve 되는 대로 채운다.
  final Map<String, String> _krwById = {};

  /// (address, chainId) 변경 시에만 재조회하기 위한 dedup 키.
  String? _lastLoadKey;

  /// 공용 목록(`wallet.assets`)이 갱신되었는지 판별하는 dedup 키 — 변경 시 1회만 KRW 재조회
  /// (iOS `.onChange(of: assets)` 대응).
  String? _lastAssetsKey;

  /// in-flight KRW 조회 가드 — 주소·체인·목록이 바뀌면 증가시켜, 이전 요청의 늦은 응답이
  /// 현재 상태를 덮어쓰지 못하게 한다 (iOS `krwGeneration` 과 동일).
  int _krwGeneration = 0;

  List<AssetRow> get _assets => widget.wallet.assets;

  /// 공용 목록 식별 키 — 자산 id + 잔액을 합쳐 만든다. 잔액만 바뀌어도 KRW 재환산이 트리거된다.
  String _assetsKey(List<AssetRow> rows) =>
      rows.map((r) => '${r.id}:${r.humanizedBalance}').join('|');

  /// 현재 공용 목록의 각 자산 KRW 환산. 자산별로 채워진다.
  Future<void> _loadKrw() async {
    final gen = ++_krwGeneration;
    if (!mounted) return;
    setState(() => _krwById.clear());
    for (final row in _assets) {
      final krw = await widget.wallet.getKrwValue(
        chainId: row.chainId,
        contractAddress: row.contractAddress,
        amount: row.humanizedBalance,
      );
      if (!mounted || gen != _krwGeneration) return;
      if (krw != null) setState(() => _krwById[row.id] = krw);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;

    // (address, accountId, chainId) 변경 시 1회만 자산 자동 조회. iOS/Android 와 동일하게 accountId 포함.
    if (wallet.address.isNotEmpty) {
      final key =
          '${wallet.address}|${wallet.selectedAccountId ?? ''}|${wallet.selectedChainId ?? ''}';
      if (key != _lastLoadKey) {
        _lastLoadKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) wallet.loadAssets();
        });
      }
    }

    // 공용 목록 갱신 시 자산별 KRW 재조회 (iOS .onChange(of: assets)).
    final assetsKey = _assetsKey(_assets);
    if (assetsKey != _lastAssetsKey) {
      _lastAssetsKey = assetsKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadKrw();
      });
    }

    final chain =
        wallet.chains.where((c) => c.chainId == wallet.selectedChainId);
    final chainName =
        chain.isEmpty ? (wallet.selectedChainId ?? '없음') : chain.first.name;

    final hint = Theme.of(context).hintColor;
    final errorColor = Theme.of(context).colorScheme.error;

    return SectionCard(
      '보유 자산',
      subtitle: '체인 $chainName',
      trailing: TextButton(
        onPressed: wallet.assetsLoading ? null : wallet.loadAssets,
        child: const Text('새로고침'),
      ),
      children: [
        if (wallet.assetsLoading)
          Text('자산 조회 중…', style: TextStyle(fontSize: 12, color: hint))
        else if (wallet.assetsError != null) ...[
          Text(wallet.assetsError!,
              style: TextStyle(fontSize: 12, color: errorColor)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: wallet.loadAssets, child: const Text('다시 시도')),
          ),
        ] else if (_assets.isEmpty)
          Text('보유 자산이 없습니다', style: TextStyle(fontSize: 12, color: hint))
        else
          for (var i = 0; i < _assets.length; i++) ...[
            _assetRow(_assets[i]),
            if (i < _assets.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerColor),
          ],
      ],
    );
  }

  Widget _assetRow(AssetRow row) {
    final hint = Theme.of(context).hintColor;
    final krw = _krwById[row.id];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(row.symbol,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          // 잔액(위) + KRW(아래) 우측 정렬.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(row.humanizedBalance,
                  style: const TextStyle(
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()])),
              if (krw != null)
                Text(krw, style: TextStyle(fontSize: 11, color: hint)),
            ],
          ),
        ],
      ),
    );
  }
}
