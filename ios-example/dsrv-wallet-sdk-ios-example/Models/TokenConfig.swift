import Foundation

struct CoinInfo {
    let name: String
    let symbol: String
    let decimals: Int
}

struct TokenInfo {
    let name: String
    let symbol: String
    let address: String
    let decimals: Int
}

struct SupportedChain {
    let chainId: String
    let displayName: String
}

enum TokenConfig {
    private static var overrides: [String: String] = [:]

    static func setOverrides(_ map: [String: String]) {
        overrides = map
    }

    static func overrideAddress(chainId: String, symbol: String) -> String? {
        overrides["\(chainId):\(symbol)"]
    }

    static let supportedChains: [SupportedChain] = [
        SupportedChain(chainId: "11155111", displayName: "Ethereum Sepolia"),
        SupportedChain(chainId: "84532", displayName: "Base Sepolia"),
        SupportedChain(chainId: "1", displayName: "Ethereum Mainnet"),
        SupportedChain(chainId: "8453", displayName: "Base Mainnet"),
    ]

    private static let ethereumCoin = CoinInfo(name: "Ethereum", symbol: "ETH", decimals: 18)
    private static let baseCoin = CoinInfo(name: "Ethereum", symbol: "ETH", decimals: 18)

    private static let ethereumSepoliaTokens: [String: TokenInfo] = [
        "USDC": TokenInfo(
            name: "Sepolia USDC",
            symbol: "USDC",
            address: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
            decimals: 6
        )
    ]

    private static let baseSepoliaTokens: [String: TokenInfo] = [
        "USDC": TokenInfo(
            name: "Base Sepolia USDC",
            symbol: "USDC",
            address: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            decimals: 6
        )
    ]

    private static let ethereumMainnetTokens: [String: TokenInfo] = [
        "USDC": TokenInfo(
            name: "USD Coin",
            symbol: "USDC",
            address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            decimals: 6
        )
    ]

    private static let baseMainnetTokens: [String: TokenInfo] = [
        "USDC": TokenInfo(
            name: "USD Coin",
            symbol: "USDC",
            address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
            decimals: 6
        )
    ]

    static func getTokensForChain(_ chainId: String) -> [String: TokenInfo] {
        switch chainId {
        case "11155111": return ethereumSepoliaTokens
        case "84532": return baseSepoliaTokens
        case "1": return ethereumMainnetTokens
        case "8453": return baseMainnetTokens
        default: return [:]
        }
    }

    static func getToken(chainId: String, symbol: String) -> TokenInfo? {
        guard let base = getTokensForChain(chainId)[symbol] else { return nil }
        if let overrideAddr = overrideAddress(chainId: chainId, symbol: symbol) {
            return TokenInfo(
                name: base.name,
                symbol: base.symbol,
                address: overrideAddr,
                decimals: base.decimals
            )
        }
        return base
    }

    static func getAvailableTokenSymbols(_ chainId: String) -> [String] {
        Array(getTokensForChain(chainId).keys).sorted()
    }

    static func getCoinForChain(_ chainId: String) -> CoinInfo? {
        switch chainId {
        case "11155111", "1": return ethereumCoin
        case "84532", "8453": return baseCoin
        default: return nil
        }
    }

    static func getRpcUrl(_ chainId: String) -> String? {
        switch chainId {
        case "11155111": return "https://ethereum-sepolia-rpc.publicnode.com"
        case "84532": return "https://sepolia.base.org"
        case "1": return "https://ethereum-rpc.publicnode.com"
        case "8453": return "https://mainnet.base.org"
        default: return nil
        }
    }
}
