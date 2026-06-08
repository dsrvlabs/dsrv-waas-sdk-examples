import 'dart:convert';

import 'package:http/http.dart' as http;

/// customer-backend `/sdk/transfer/build-hash`, `/sdk/transfer/broadcast` 호출 client.
///
/// customer-backend 가 자체 server-key (`X_API_KEY`) 로 WaaS 와 통신하므로 example 은 user
/// token 을 보내지 않는다. sign 단계만 SDK 의 `DSRVWallet.sign` 으로 직접 수행.
class TransferRepository {
  final String backendUrl;
  TransferRepository(this.backendUrl);

  Future<BuildTransferResponse> buildHash(BuildTransferRequest request) async {
    final response = await _post('/sdk/transfer/build-hash', request.toJson());
    return BuildTransferResponse.fromJson(response);
  }

  Future<BroadcastTransferResponse> broadcast(
      BroadcastTransferRequest request) async {
    final response = await _post('/sdk/transfer/broadcast', request.toJson());
    return BroadcastTransferResponse.fromJson(response);
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse('$backendUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('$path [${resp.statusCode}]: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

/// `POST /sdk/transfer/build-hash` request.
class BuildTransferRequest {
  final String fromAddress;
  final String toAddress;

  /// wei (base units, 정수 문자열).
  final String amount;

  /// EVM chainId (문자열).
  final String chainId;

  /// ERC-20 컨트랙트 주소 — null 이면 native 전송.
  final String? contractAddress;

  const BuildTransferRequest({
    required this.fromAddress,
    required this.toAddress,
    required this.amount,
    required this.chainId,
    this.contractAddress,
  });

  Map<String, dynamic> toJson() => {
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'amount': amount,
        'chainId': chainId,
        if (contractAddress != null) 'contractAddress': contractAddress,
      };
}

/// `POST /sdk/transfer/build-hash` response.
class BuildTransferResponse {
  /// broadcast path 파라미터 (BTX-...).
  final String txId;

  /// MPC sign 의 id 슬롯에 그대로 넘김 — TRANSACTION 이면 TX-..., CONTRACT_CALL 이면 EXE-...
  final String signId;

  /// 서명 대상 keccak256 hash (0x-hex).
  final String messageHash;

  /// 서명 대상 message 종류 — TRANSACTION | CONTRACT_CALL.
  final String type;

  const BuildTransferResponse({
    required this.txId,
    required this.signId,
    required this.messageHash,
    required this.type,
  });

  factory BuildTransferResponse.fromJson(Map<String, dynamic> json) =>
      BuildTransferResponse(
        txId: json['txId'] as String,
        signId: json['signId'] as String,
        messageHash: json['messageHash'] as String,
        type: json['type'] as String,
      );
}

/// `POST /sdk/transfer/broadcast` request.
class BroadcastTransferRequest {
  final String txId;

  const BroadcastTransferRequest({required this.txId});

  Map<String, dynamic> toJson() => {'txId': txId};
}

/// `POST /sdk/transfer/broadcast` response.
///
/// [txHash] 는 EIP-7702 bundler 경로일 때 응답 시점에 아직 발급 안 됨 (null).
/// 이 때 [status] == "SIGNED" 이며 bundler 가 별도 시점에 onchain 전송 → 후속 polling 필요.
/// 일반 EOA 경로는 즉시 [txHash] 가 채워지고 [status] == "BROADCAST".
class BroadcastTransferResponse {
  final String? txHash;
  final String status;
  final String batchTxId;

  const BroadcastTransferResponse({
    this.txHash,
    required this.status,
    required this.batchTxId,
  });

  factory BroadcastTransferResponse.fromJson(Map<String, dynamic> json) =>
      BroadcastTransferResponse(
        txHash: json['txHash'] as String?,
        status: json['status'] as String? ?? '',
        batchTxId: json['batchTxId'] as String? ?? '',
      );
}
