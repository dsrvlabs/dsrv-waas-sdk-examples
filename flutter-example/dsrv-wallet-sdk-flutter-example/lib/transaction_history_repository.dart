import 'dart:convert';

import 'package:http/http.dart' as http;

/// customer-backend `GET /sdk/transactions` 호출 client — transaction history 조회.
///
/// customer-backend 가 자체 server-key (`X_API_KEY`) 로 WaaS 의
/// `GET /api/v1/embedded-wallets/ncw/transactions` (fromAddress 필터) 를 호출하므로
/// example 은 user token 을 보내지 않는다 (`TransferRepository` 와 동일 패턴).
class TransactionHistoryRepository {
  final String backendUrl;
  TransactionHistoryRepository(this.backendUrl);

  /// [address] 조회 대상 지갑 주소 (fromAddress 필터).
  /// [page] 1-base 페이지 번호. [limit] 페이지당 항목 수 (WaaS 최대 100).
  Future<TransactionHistoryResponse> getTransactions({
    required String address,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$backendUrl/sdk/transactions').replace(
      queryParameters: {
        'address': address,
        'page': '$page',
        'limit': '$limit',
      },
    );
    final resp = await http.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('/sdk/transactions [${resp.statusCode}]: ${resp.body}');
    }
    return TransactionHistoryResponse.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

/// `GET /sdk/transactions` response item — WaaS EwTransactionInfo 와 1:1.
class TransactionHistoryItem {
  /// WaaS 트랜잭션 비즈니스 키 (TX-...).
  final String transactionId;
  final String chainId;

  /// 체인 계열 식별자 (EVM 등).
  final String chainType;

  /// 트랜잭션 상태 그룹 (PENDING / COMPLETED / FAILED 등).
  final String status;
  final String fromAddress;
  final String? toAddress;

  /// onchain hash — 브로드캐스트 전이면 null.
  final String? txHash;

  /// 트랜잭션 종류 (transfer 등).
  final String? method;

  /// ISO 8601 생성 시각.
  final String createdAt;

  const TransactionHistoryItem({
    required this.transactionId,
    required this.chainId,
    required this.chainType,
    required this.status,
    required this.fromAddress,
    this.toAddress,
    this.txHash,
    this.method,
    required this.createdAt,
  });

  factory TransactionHistoryItem.fromJson(Map<String, dynamic> json) =>
      TransactionHistoryItem(
        transactionId: json['transactionId'] as String? ?? '',
        chainId: json['chainId'] as String? ?? '',
        chainType: json['chainType'] as String? ?? '',
        status: json['status'] as String? ?? '',
        fromAddress: json['fromAddress'] as String? ?? '',
        toAddress: json['toAddress'] as String?,
        txHash: json['txHash'] as String?,
        method: json['method'] as String?,
        createdAt: json['createdAt'] as String? ?? '',
      );
}

class TransactionHistoryPagination {
  final int page;
  final int limit;
  final int total;

  const TransactionHistoryPagination({
    required this.page,
    required this.limit,
    required this.total,
  });

  factory TransactionHistoryPagination.fromJson(Map<String, dynamic> json) =>
      TransactionHistoryPagination(
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

/// `GET /sdk/transactions` response.
class TransactionHistoryResponse {
  final List<TransactionHistoryItem> items;
  final TransactionHistoryPagination pagination;

  const TransactionHistoryResponse({
    required this.items,
    required this.pagination,
  });

  factory TransactionHistoryResponse.fromJson(Map<String, dynamic> json) =>
      TransactionHistoryResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => TransactionHistoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: TransactionHistoryPagination.fromJson(
            json['pagination'] as Map<String, dynamic>? ?? const {}),
      );
}
