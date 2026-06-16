import 'dart:convert';

import 'package:http/http.dart' as http;

/// customer-backend `GET /sdk/asset/by-chain/latest-value` 호출 client — 보유 자산의 법정통화 환산값 조회.
///
/// customer-backend 가 price-hub 의 동일 endpoint 로 중계한다. `contractAddress` 생략 시 native 토큰.
/// 금액 필드(price.value / holdings.amount / holdings.totalValue)는 price-hub 가 BigDecimal 을
/// JSON number 로 직렬화하므로 number/string 양쪽 모두 허용해 디코드한다 (`TransactionHistoryRepository` 동일 패턴).
class AssetValueRepository {
  final String backendUrl;
  AssetValueRepository(this.backendUrl);

  /// [chainId] 필수. [contractAddress] null 이면 native 토큰 조회 (쿼리에서 생략).
  /// [amount] humanized decimal 문자열 (예: "0.5"). [currency] 는 KRW 고정.
  Future<LatestValueByChainResponse> getLatestValue({
    required String chainId,
    String? contractAddress,
    String currency = 'KRW',
    required String amount,
  }) async {
    final uri = Uri.parse('$backendUrl/sdk/asset/by-chain/latest-value').replace(
      queryParameters: {
        'chainId': chainId,
        if (contractAddress != null) 'contractAddress': contractAddress,
        'currency': currency,
        'amount': amount,
      },
    );
    // Android/iOS 와 동일하게 15s 타임아웃 (네트워크 무응답 시 UI 무한 대기 방지).
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          '/sdk/asset/by-chain/latest-value [${resp.statusCode}]: ${resp.body}');
    }
    return LatestValueByChainResponse.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

/// JSON number 또는 string 으로 올 수 있는 금액 필드를 문자열로 정규화.
String? _numOrString(dynamic v) => v is num ? v.toString() : v is String ? v : null;

/// price-hub AssetByChainInfo 와 1:1.
class AssetByChainInfo {
  final String chainId;
  final String chainName;

  /// native 토큰이면 null.
  final String? contractAddress;
  final String symbol;
  final String name;

  /// ERC20 / NATIVE 등.
  final String? tokenStandard;

  /// native 토큰이면 null 일 수 있음.
  final int? decimals;

  const AssetByChainInfo({
    required this.chainId,
    required this.chainName,
    this.contractAddress,
    required this.symbol,
    required this.name,
    this.tokenStandard,
    this.decimals,
  });

  factory AssetByChainInfo.fromJson(Map<String, dynamic> json) =>
      AssetByChainInfo(
        chainId: json['chainId'] as String? ?? '',
        chainName: json['chainName'] as String? ?? '',
        contractAddress: json['contractAddress'] as String?,
        symbol: json['symbol'] as String? ?? '',
        name: json['name'] as String? ?? '',
        tokenStandard: json['tokenStandard'] as String?,
        decimals: (json['decimals'] as num?)?.toInt(),
      );
}

class LatestPriceData {
  final String currency;
  final String? value;

  /// 가격 기준 시각 (ISO 8601).
  final String fetchedAt;

  /// 가격 출처 (REDIS / DB / API).
  final String source;

  const LatestPriceData({
    required this.currency,
    this.value,
    required this.fetchedAt,
    required this.source,
  });

  factory LatestPriceData.fromJson(Map<String, dynamic> json) =>
      LatestPriceData(
        currency: json['currency'] as String? ?? '',
        value: _numOrString(json['value']),
        fetchedAt: json['fetchedAt'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );
}

class Holdings {
  final String? amount;
  final String? totalValue;

  const Holdings({this.amount, this.totalValue});

  factory Holdings.fromJson(Map<String, dynamic> json) => Holdings(
        amount: _numOrString(json['amount']),
        totalValue: _numOrString(json['totalValue']),
      );
}

/// `GET /sdk/asset/by-chain/latest-value` response.
class LatestValueByChainResponse {
  final AssetByChainInfo asset;
  final LatestPriceData price;

  /// amount=0(또는 생략)이면 price-hub 가 생략 — 가격만 반환된다.
  final Holdings? holdings;

  const LatestValueByChainResponse({
    required this.asset,
    required this.price,
    this.holdings,
  });

  factory LatestValueByChainResponse.fromJson(Map<String, dynamic> json) =>
      LatestValueByChainResponse(
        asset: AssetByChainInfo.fromJson(
            json['asset'] as Map<String, dynamic>? ?? const {}),
        price: LatestPriceData.fromJson(
            json['price'] as Map<String, dynamic>? ?? const {}),
        holdings: json['holdings'] == null
            ? null
            : Holdings.fromJson(json['holdings'] as Map<String, dynamic>),
      );
}
