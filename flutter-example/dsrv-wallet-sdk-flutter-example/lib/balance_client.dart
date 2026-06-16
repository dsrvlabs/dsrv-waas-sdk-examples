import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_config.dart';

/// 읽기 전용 JSON-RPC 클라이언트 — 잔액 조회용.
///
/// Android [`BalanceClient.kt`](../../android/dsrv-wallet-sdk-android-example/app/src/main/java/com/dsrv/wallet/example/wallet/model/BalanceClient.kt) 대응.
/// RPC URL 은 [TokenConfig.getRpcUrl] 매핑. 트랜잭션 전송은 SDK 가 별도 처리.
class BalanceClient {
  /// 네이티브 코인 (ETH 등) 잔액 — wei.
  Future<BigInt> getNativeBalance(String chainId, String address) async {
    final url = TokenConfig.getRpcUrl(chainId);
    if (url == null) {
      throw Exception('chainId=$chainId 의 RPC URL 이 정의되지 않았습니다');
    }
    final payload = {
      'jsonrpc': '2.0',
      'method': 'eth_getBalance',
      'params': [address, 'latest'],
      'id': 1,
    };
    return _callRpc(url, payload);
  }

  /// ERC-20 잔액 — base units. balanceOf(address) 호출 (selector 0x70a08231).
  Future<BigInt> getErc20Balance(
    String chainId,
    String tokenAddress,
    String ownerAddress,
  ) async {
    final url = TokenConfig.getRpcUrl(chainId);
    if (url == null) {
      throw Exception('chainId=$chainId 의 RPC URL 이 정의되지 않았습니다');
    }
    final ownerNo0x =
        ownerAddress.replaceFirst(RegExp(r'^0x'), '').toLowerCase().padLeft(64, '0');
    final data = '0x70a08231$ownerNo0x';
    final payload = {
      'jsonrpc': '2.0',
      'method': 'eth_call',
      'params': [
        {'to': tokenAddress, 'data': data},
        'latest',
      ],
      'id': 1,
    };
    return _callRpc(url, payload);
  }

  Future<BigInt> _callRpc(String url, Map<String, dynamic> payload) async {
    // Android/iOS BalanceClient 와 동일하게 15s 타임아웃 (RPC 무응답 시 무한 대기 방지).
    final resp = await http
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final root = jsonDecode(resp.body) as Map<String, dynamic>;
    final error = root['error'];
    if (error != null) {
      final message =
          error is Map<String, dynamic> ? error['message'] : null;
      throw Exception('RPC error: ${message ?? resp.body}');
    }
    final hex = root['result'] as String?;
    if (hex == null) {
      throw Exception('missing result: ${resp.body}');
    }
    return _parseHexToBigInt(hex);
  }

  BigInt _parseHexToBigInt(String hex) {
    final clean = hex.replaceFirst(RegExp(r'^0x'), '');
    return BigInt.parse(clean.isEmpty ? '0' : clean, radix: 16);
  }
}
