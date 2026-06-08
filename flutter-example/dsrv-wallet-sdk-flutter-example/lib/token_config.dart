/// 네트워크별 코인/토큰 설정.
///
/// Android [`TokenConfig.kt`](../../android/dsrv-wallet-sdk-android-example/app/src/main/java/com/dsrv/wallet/example/wallet/config/TokenConfig.kt)
/// / iOS [`TokenConfig.swift`](../../ios/dsrv-wallet-sdk-ios-example/dsrv-wallet-sdk-ios-example/Models/TokenConfig.swift) 와 동일한 데이터를 둔다.
library;

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
}
