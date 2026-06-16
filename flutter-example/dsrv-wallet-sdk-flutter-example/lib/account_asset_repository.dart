import 'dart:convert';

import 'package:http/http.dart' as http;

import 'amount.dart';

/// customer-backend `GET /sdk/asset/accounts/{accountId}` 호출 client —
/// WaaS 계정 자산 목록(계정의 모든 주소 잔고를 chain·asset 단위로 합산)을 조회한다. 기존 RPC 직접 호출(`BalanceClient`)을 대체.
///
/// customer-backend 가 자체 server-key (`X_API_KEY`) 로 WaaS 의
/// `GET /api/v1/embedded-wallets/ncw/accounts/{accountId}/assets` 를
/// 호출하므로 example 은 user token 을 보내지 않는다 (`TransactionHistoryRepository`/
/// `AssetValueRepository` 와 동일 패턴). userId·addressId 불필요 — projectId(passport) + accountId 로 스코핑.
class AccountAssetRepository {
  final String backendUrl;
  AccountAssetRepository(this.backendUrl);

  /// [accountId] 로 해당 계정의 보유 자산 목록(모든 주소·체인 합산)을 조회한다.
  Future<AccountAssetsResponse> getAccountAssets({
    required String accountId,
  }) async {
    final uri = Uri.parse('$backendUrl/sdk/asset/accounts/$accountId');
    // Android/iOS 와 동일하게 15s 타임아웃 (네트워크 무응답 시 UI 무한 대기 방지).
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          '/sdk/asset/accounts/$accountId [${resp.statusCode}]: ${resp.body}');
    }
    return AccountAssetsResponse.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

/// `GET /sdk/asset/accounts/{accountId}` response item — WaaS AccountAssetInfo 와 1:1.
class AccountAssetItem {
  final String chainId;

  /// 체인 계열 (EVM / SVM).
  final String chainType;

  /// 토큰 컨트랙트 주소. native 코인은 null.
  final String? contractAddress;

  /// raw smallest-unit 잔고 (wei 등, decimals 미적용). 정밀도 보존 위해 string.
  final String balance;

  /// WaaS 가 제공할 때만 존재하는 자산 심볼(예: "ETH","USDC"). 없으면 앱이 price-hub 로 보완.
  final String? symbol;

  const AccountAssetItem({
    required this.chainId,
    required this.chainType,
    this.contractAddress,
    required this.balance,
    this.symbol,
  });

  factory AccountAssetItem.fromJson(Map<String, dynamic> json) =>
      AccountAssetItem(
        chainId: json['chainId'] as String? ?? '',
        chainType: json['chainType'] as String? ?? '',
        contractAddress: json['contractAddress'] as String?,
        balance: json['balance'] as String? ?? '0',
        symbol: json['symbol'] as String?,
      );
}

class AccountAssetsPagination {
  final int page;
  final int limit;
  final int total;

  const AccountAssetsPagination({
    required this.page,
    required this.limit,
    required this.total,
  });

  factory AccountAssetsPagination.fromJson(Map<String, dynamic> json) =>
      AccountAssetsPagination(
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /sdk/asset/accounts/{accountId}` response.
class AccountAssetsResponse {
  final List<AccountAssetItem> items;
  final AccountAssetsPagination pagination;

  const AccountAssetsResponse({
    required this.items,
    required this.pagination,
  });

  factory AccountAssetsResponse.fromJson(Map<String, dynamic> json) =>
      AccountAssetsResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => AccountAssetItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: AccountAssetsPagination.fromJson(
            json['pagination'] as Map<String, dynamic>? ?? const {}),
      );
}

/// 드롭다운 한 줄에 필요한 자산 표시 정보 — WaaS 자산(raw balance) + price-hub 메타(symbol/decimals)
/// 를 합쳐 만든다. symbol/name/decimals 는 price-hub `by-chain/latest-value` 응답에서 온다
/// (WaaS 자산 API 는 이 메타를 주지 않음).
class AssetRow {
  final String chainId;

  /// native 코인은 null.
  final String? contractAddress;

  /// raw smallest-unit 잔고 (decimals 미적용). 정밀도 보존 위해 string.
  final String rawBalance;
  final String symbol;
  final String name;
  final int decimals;

  /// decimals 적용된 사람이 읽는 잔고 ("1.5").
  final String humanizedBalance;

  const AssetRow({
    required this.chainId,
    this.contractAddress,
    required this.rawBalance,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.humanizedBalance,
  });

  /// (chainId, contractAddress) 조합이 자산 고유키. native 는 "native".
  String get id =>
      '$chainId:${(contractAddress ?? 'native').toLowerCase()}';

  bool get isNative => contractAddress == null || contractAddress!.isEmpty;

  /// 드롭다운 라벨: 심볼만("ETH"). 잔액은 별도 잔액 row 에 표시.
  String get displayLabel => symbol;
}

/// 자산 1건 + price-hub 메타(symbol/name/decimals)를 합쳐 [AssetRow] 로 만든다.
///
/// 심볼 우선순위: ① WaaS([item.symbol], 정확) ② price-hub([symbol]) ③ 체인 계열 fallback(native→ETH/SOL,
/// 토큰→"TOKEN"). decimals 는 WaaS 가 안 주므로 항상 price-hub([decimals]) 에서 받고, 없으면 native 18 /
/// 토큰 0(raw 표시)으로 폴백한다.
AssetRow buildAssetRow(
  AccountAssetItem item, {
  String? symbol,
  String? name,
  int? decimals,
}) {
  final isNative =
      item.contractAddress == null || item.contractAddress!.isEmpty;
  final resolvedDecimals = decimals ?? (isNative ? 18 : 0);
  // 심볼은 표준 티커 표기(대문자)로 통일 — price-hub 가 "usdc" 처럼 소문자로 줄 수 있음.
  final hasWaasSymbol = item.symbol != null && item.symbol!.trim().isNotEmpty;
  final hasSymbol = symbol != null && symbol.trim().isNotEmpty;
  // ① WaaS 심볼 우선 ② price-hub 심볼 ③ fallback(native→체인 기본, 토큰→"TOKEN").
  final resolvedSymbol = hasWaasSymbol
      ? item.symbol!.trim().toUpperCase()
      : (hasSymbol
          ? symbol.trim().toUpperCase()
          : (isNative ? _nativeFallbackSymbol(item.chainType) : 'TOKEN'));
  final humanized = resolvedDecimals > 0
      ? fromBaseUnits(BigInt.parse(item.balance), resolvedDecimals)
      : item.balance;
  return AssetRow(
    chainId: item.chainId,
    contractAddress: isNative ? null : item.contractAddress,
    rawBalance: item.balance,
    symbol: resolvedSymbol,
    name: name ?? resolvedSymbol,
    decimals: resolvedDecimals,
    humanizedBalance: humanized,
  );
}

/// price-hub 메타가 없을 때 native 코인의 표시 심볼 — 체인 계열 기준 (price-hub 가 심볼을 주면 그 값 우선).
/// 현재 지원 체인은 모두 EVM=ETH. 향후 다른 native 체인은 price-hub 시세로 정확히 표기됨.
String _nativeFallbackSymbol(String chainType) {
  switch (chainType.toUpperCase()) {
    case 'SVM':
    case 'SOLANA':
      return 'SOL';
    default:
      return 'ETH';
  }
}
