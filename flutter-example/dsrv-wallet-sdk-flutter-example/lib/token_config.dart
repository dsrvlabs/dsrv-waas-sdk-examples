/// 네트워크별 코인/토큰 설정.
///
/// Android [`TokenConfig.kt`](../../android/dsrv-wallet-sdk-android-example/app/src/main/java/com/dsrv/wallet/example/wallet/config/TokenConfig.kt)
/// / iOS [`TokenConfig.swift`](../../ios/dsrv-wallet-sdk-ios-example/dsrv-wallet-sdk-ios-example/Models/TokenConfig.swift) 와 동일한 데이터를 둔다.
library;

import 'config.dart';

class TokenInfo {
  final String name;
  final String symbol;
  final String address;
  final int decimals;
  const TokenInfo({
    required this.name,
    required this.symbol,
    required this.address,
    required this.decimals,
  });
}

class TokenConfig {
  // Ethereum Sepolia (chainId: 11155111)
  static const _ethereumSepoliaTokens = <String, TokenInfo>{
    'USDC': TokenInfo(
      name: 'Sepolia USDC',
      symbol: 'USDC',
      address: '0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238',
      decimals: 6,
    ),
  };

  // Base Sepolia (chainId: 84532)
  static const _baseSepoliaTokens = <String, TokenInfo>{
    'USDC': TokenInfo(
      name: 'Base Sepolia USDC',
      symbol: 'USDC',
      address: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      decimals: 6,
    ),
  };

  // Ethereum Mainnet (chainId: 1)
  static const _ethereumMainnetTokens = <String, TokenInfo>{
    'USDC': TokenInfo(
      name: 'USD Coin',
      symbol: 'USDC',
      address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      decimals: 6,
    ),
  };

  // Base Mainnet (chainId: 8453)
  static const _baseMainnetTokens = <String, TokenInfo>{
    'USDC': TokenInfo(
      name: 'USD Coin',
      symbol: 'USDC',
      address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
      decimals: 6,
    ),
  };

  static Map<String, TokenInfo> getTokensForChain(String chainId) {
    switch (chainId) {
      case '11155111':
        return _ethereumSepoliaTokens;
      case '84532':
        return _baseSepoliaTokens;
      case '1':
        return _ethereumMainnetTokens;
      case '8453':
        return _baseMainnetTokens;
      default:
        return const {};
    }
  }

  static TokenInfo? getToken(String chainId, String symbol) =>
      getTokensForChain(chainId)[symbol];

  static List<String> getAvailableTokenSymbols(String chainId) =>
      getTokensForChain(chainId).keys.toList();

  /// chainId 에 대응되는 공용 RPC 엔드포인트 URL.
  /// 잔액 조회 / 읽기 전용 호출용 — 트랜잭션 전송은 SDK 가 별도 처리.
  /// 엔드포인트는 [AppConfig.rpcUrls] 에서 주입받는다 (`--dart-define=RPC_URL_<chainId>` 로 덮어쓰기 가능).
  static String? getRpcUrl(String chainId) => AppConfig.rpcUrls[chainId];
}

/// base units BigInt → 사람이 읽는 십진 표기. 뒤쪽 0 은 trim, 정수면 "." 도 제거.
///
/// Android [`Amount.kt`](../../android/dsrv-wallet-sdk-android-example/app/src/main/java/com/dsrv/wallet/example/wallet/model/Amount.kt) `fromBaseUnits` 대응.
/// fromBaseUnits(BigInt.parse("100000"), 6) == "0.1"
/// fromBaseUnits(BigInt.parse("1000000"), 6) == "1"
String fromBaseUnits(BigInt amount, int decimals) {
  if (decimals <= 0) return amount.toString();
  final s = amount.toString().padLeft(decimals + 1, '0');
  final whole = s.substring(0, s.length - decimals);
  final frac = s.substring(s.length - decimals).replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? whole : '$whole.$frac';
}
