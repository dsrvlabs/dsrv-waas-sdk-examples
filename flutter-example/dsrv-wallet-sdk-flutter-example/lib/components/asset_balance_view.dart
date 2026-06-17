import 'package:flutter/material.dart';

import '../account_asset_repository.dart';
import '../wallet_state.dart';

/// iOS `AssetBalanceView.swift` 대응 — 자산 드롭다운 + 선택 자산 잔액 + KRW 환산.
/// 전송 화면과 지갑상세 요약카드에서 공용으로 쓴다.
///
/// 자산 목록/로딩/에러는 [WalletState](공용)에서 **관찰**하고(목록 적재는 [WalletState.loadAssets]),
/// 화면별 상태(선택 자산·KRW)만 View 가 보관한다. 선택된 자산은 [onSelected] 콜백으로 부모(전송)에 전달한다.
/// 표시 전용(요약카드)이면 [onSelected] 없이 생성하면 된다.
class AssetBalanceView extends StatefulWidget {
  final WalletState wallet;
  final ValueChanged<AssetRow?>? onSelected;
  const AssetBalanceView({required this.wallet, this.onSelected, super.key});

  @override
  State<AssetBalanceView> createState() => _AssetBalanceViewState();
}

class _AssetBalanceViewState extends State<AssetBalanceView> {
  // 선택 자산 id (화면별 상태) — 목록/로딩/에러는 공용 [WalletState] 에서 관찰.
  String? _selectedAssetId;

  /// 보유분 KRW 환산 (이미 "₩" 포함 포맷 문자열). 잔액 0 또는 조회 실패면 null.
  String? _krwValue;
  bool _krwLoading = false;

  /// (address, chainId) 변경 시에만 재조회하기 위한 dedup 키.
  String? _lastLoadKey;

  /// 공용 목록(`wallet.assets`)이 갱신되었는지 판별하는 dedup 키 — 변경 시 1회만
  /// 선택 보정 + 부모 전달 + KRW 갱신 (iOS `.onChange(of: assets)` 대응).
  String? _lastAssetsKey;

  /// in-flight KRW 조회 가드 — 선택/목록이 바뀌면 증가시켜, 이전 요청의 늦은 응답이
  /// 현재 상태를 덮어쓰지 못하게 한다 (iOS `krwGeneration` 과 동일).
  int _krwGeneration = 0;

  List<AssetRow> get _assets => widget.wallet.assets;

  AssetRow? get _selectedAsset {
    final matched = _assets.where((a) => a.id == _selectedAssetId);
    if (matched.isNotEmpty) return matched.first;
    // 저장된 선택이 없거나(첫 로드) 목록에 없으면 첫 자산을 기본 선택 — 드롭다운/잔액/KRW 가
    // 사용자 조작 없이도 즉시 첫 자산을 가리키게 한다(첫 프레임 blank 회피).
    return _assets.isEmpty ? null : _assets.first;
  }

  /// 공용 목록 식별 키 — 자산 id + 잔액을 합쳐 만든다. 목록뿐 아니라 잔액만 바뀌어도 키가 바뀌어
  /// KRW 재환산이 트리거된다(iOS/Android 는 AssetRow 전체 동등성으로 처리).
  String _assetsKey(List<AssetRow> rows) =>
      rows.map((r) => '${r.id}:${r.humanizedBalance}').join('|');

  /// 공용 목록이 갱신되면 선택 자산을 보정(없으면 첫 자산) → 부모 전달 → KRW 갱신.
  void _syncSelection() {
    if (_selectedAssetId == null ||
        !_assets.any((r) => r.id == _selectedAssetId)) {
      _selectedAssetId = _assets.isEmpty ? null : _assets.first.id;
    }
    widget.onSelected?.call(_selectedAsset);
    _refreshKrw();
  }

  /// 선택 자산의 잔액 → KRW 환산 (price-hub). 실패/미가용 시 null (잔액은 그대로 표시).
  Future<void> _refreshKrw() async {
    final gen = ++_krwGeneration;
    final asset = _selectedAsset;
    if (!mounted) return;
    setState(() {
      _krwValue = null;
      _krwLoading = asset != null;
    });
    if (asset == null) return;
    final krw = await widget.wallet.getKrwValue(
      chainId: asset.chainId,
      contractAddress: asset.contractAddress,
      amount: asset.humanizedBalance,
    );
    if (!mounted || gen != _krwGeneration) return;
    setState(() {
      _krwValue = krw;
      _krwLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;

    // (address, accountId, chainId) 변경 시 1회만 자산 자동 조회. iOS/Android 와 동일하게 accountId 포함
    // (계정 전환 시 주소가 그대로여도 목록을 새로 받도록).
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

    // 공용 목록(wallet.assets) 갱신 시 선택 보정 + 부모 전달 + KRW 갱신 (iOS .onChange(of: assets)).
    final assetsKey = _assetsKey(_assets);
    if (assetsKey != _lastAssetsKey) {
      _lastAssetsKey = assetsKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncSelection();
      });
    }

    final hint = Theme.of(context).hintColor;
    final errorColor = Theme.of(context).colorScheme.error;
    final asset = _selectedAsset;
    // DropdownButton.value 는 items 에 존재해야 함(없으면 assertion 크래시). 기본 선택(첫 자산)을 반영하는
    // _selectedAsset.id 를 쓰면 첫 프레임부터 collapsed 라벨이 첫 자산을 표시한다(목록 비면 null → 미표시).
    final safeSelectedId = _selectedAsset?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wallet.assetsLoading)
          Text('자산 조회 중…', style: TextStyle(fontSize: 11, color: hint))
        else if (wallet.assetsError != null) ...[
          Text(wallet.assetsError!,
              style: TextStyle(fontSize: 11, color: errorColor)),
          TextButton(
              onPressed: wallet.loadAssets, child: const Text('다시 시도')),
        ] else if (_assets.isEmpty)
          Text('보유 자산이 없습니다', style: TextStyle(fontSize: 11, color: hint))
        else
          SizedBox(
            width: double.infinity,
            child: DropdownButton<String>(
              isExpanded: true,
              value: safeSelectedId,
              items: [
                for (final a in _assets)
                  DropdownMenuItem(value: a.id, child: Text(a.displayLabel)),
              ],
              onChanged: (sel) {
                if (sel == null) return;
                setState(() => _selectedAssetId = sel);
                widget.onSelected?.call(_selectedAsset);
                _refreshKrw();
              },
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('현재 잔액', style: TextStyle(fontSize: 11, color: hint)),
                  if (asset != null)
                    Text('${asset.humanizedBalance} ${asset.symbol}',
                        style: TextStyle(fontSize: 11, color: hint))
                  else
                    Text('—', style: TextStyle(fontSize: 11, color: hint)),
                  if (_krwLoading)
                    Text('환산 중…', style: TextStyle(fontSize: 11, color: hint))
                  else if (_krwValue != null)
                    Text(_krwValue!, style: TextStyle(fontSize: 11, color: hint)),
                ],
              ),
            ),
            TextButton(
              onPressed: wallet.assetsLoading ? null : wallet.loadAssets,
              child: const Text('새로고침'),
            ),
          ],
        ),
      ],
    );
  }
}
