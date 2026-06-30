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

/// `POST /payments` 의 한쪽 endpoint (출금=source / 수령=destination).
///
/// cross-chain: source 와 destination 이 서로 다른 체인일 수 있어 chain/token/주소를
/// endpoint 단위로 받는다. 같은 USDC 라도 컨트랙트 주소는 체인마다 달라 [tokenAddress] 도 endpoint 별.
class PaymentEndpoint {
  final int chainId;
  final String tokenAddress;

  /// source = payer(NCW) 주소, destination = 수령자 주소.
  final String address;

  const PaymentEndpoint({
    required this.chainId,
    required this.tokenAddress,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
        'chainId': chainId,
        'tokenAddress': tokenAddress,
        'address': address,
      };
}

/// `POST /payments` request — Topup 결제 (cross-chain).
///
/// 출금([source]) / 수령([destination]) 을 분리해 보낸다. same-chain 결제는 두 endpoint 의
/// chainId/tokenAddress 를 동일하게 보내면 된다.
class PaymentRequest {
  final String sourceUserId;
  final PaymentEndpoint source;
  final PaymentEndpoint destination;

  /// humanized 문자열 (예: "1.5"). 단위 변환(wei)은 stablecoin Payments 가 담당.
  final String amount;

  /// 0 = 일반 결제.
  final int paymentType;

  const PaymentRequest({
    required this.sourceUserId,
    required this.source,
    required this.destination,
    required this.amount,
    required this.paymentType,
  });

  Map<String, dynamic> toJson() => {
        'sourceUserId': sourceUserId,
        'source': source.toJson(),
        'destination': destination.toJson(),
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
