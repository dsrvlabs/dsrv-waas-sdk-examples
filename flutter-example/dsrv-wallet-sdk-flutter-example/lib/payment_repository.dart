import 'dart:convert';

import 'package:http/http.dart' as http;

/// customer-backend `POST /payments` 호출 client.
///
/// customer-backend 가 내부에서 stablecoin Payments quote → paymentDigest 서명(고객사 PK) → execute
/// 를 한 번에 처리. 클라이언트는 paymentDigest 서명을 직접 하지 않는다.
class PaymentRepository {
  final String backendUrl;
  PaymentRepository(this.backendUrl);

  Future<PaymentResponse> pay(PaymentRequest request) async {
    final resp = await http.post(
      Uri.parse('$backendUrl/payments'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('/payments [${resp.statusCode}]: ${resp.body}');
    }
    return PaymentResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

/// `POST /payments` request — Topup 결제.
class PaymentRequest {
  final String sourceUserId;
  final int chainId;
  final String token;
  final String from;
  final String to;

  /// humanized 문자열 (예: "1.5"). 단위 변환(wei)은 stablecoin Payments 가 담당.
  final String amount;

  /// 0 = 일반 결제.
  final int paymentType;

  const PaymentRequest({
    required this.sourceUserId,
    required this.chainId,
    required this.token,
    required this.from,
    required this.to,
    required this.amount,
    required this.paymentType,
  });

  Map<String, dynamic> toJson() => {
        'sourceUserId': sourceUserId,
        'chainId': chainId,
        'token': token,
        'from': from,
        'to': to,
        'amount': amount,
        'paymentType': paymentType,
      };
}

/// `POST /payments` response — stablecoin Payments transaction 결과.
///
/// [txHash] 는 EIP-7702 bundler 경로 또는 비동기 broadcast 일 때 응답 시점에
/// 아직 발급 안 될 수 있어 nullable. status 가 SIGNED/PENDING 이면 후속 polling 필요.
class PaymentResponse {
  final String transactionId;
  final String paymentUuid;
  final String status;
  final String? txHash;
  final String? submittedAt;

  const PaymentResponse({
    required this.transactionId,
    required this.paymentUuid,
    required this.status,
    this.txHash,
    this.submittedAt,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) => PaymentResponse(
        transactionId: json['transactionId'] as String,
        paymentUuid: json['paymentUuid'] as String,
        status: json['status'] as String,
        txHash: json['txHash'] as String?,
        submittedAt: json['submittedAt'] as String?,
      );
}
