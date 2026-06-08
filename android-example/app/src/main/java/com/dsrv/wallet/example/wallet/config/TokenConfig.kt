package com.dsrv.wallet.example.wallet.config

/**
 * 자산 유형
 */
enum class AssetType {
    COIN,
    TOKEN
}

/**
 * 코인 정보 (ETH 등 네이티브 코인)
 */
data class CoinInfo(
    val name: String,
    val symbol: String,
    val decimals: Int = 18
)

/**
 * 토큰 정보
 */
data class TokenInfo(
    val name: String,
    val symbol: String,
    val address: String,
    val decimals: Int
)

/**
 * 지원 체인 메타데이터 (UI 에서 enumerate 용).
 */
data class SupportedChain(val chainId: String, val displayName: String)

/**
 * 네트워크별 코인/토큰 설정 관리.
 *
 * 기본값은 hardcoded, 사용자가 설정 탭에서 수정한 override 는 [overrides] 에 저장되어
 * [getToken] 시 우선 적용된다 (key: "chainId:symbol", value: address).
 */
object TokenConfig {
    private var overrides: Map<String, String> = emptyMap()

    /** 외부(Wallet ViewModel) 가 prefs 에서 로드한 override 를 주입. */
    fun setOverrides(map: Map<String, String>) {
        overrides = map
    }

    fun overrideAddress(chainId: String, symbol: String): String? =
        overrides["$chainId:$symbol"]

    val supportedChains: List<SupportedChain> = listOf(
        SupportedChain("11155111", "Ethereum Sepolia"),
        SupportedChain("84532", "Base Sepolia"),
        SupportedChain("1", "Ethereum Mainnet"),
        SupportedChain("8453", "Base Mainnet"),
    )

    // 네이티브 코인 설정
    private val ethereumCoin = CoinInfo(
        name = "Ethereum",
        symbol = "ETH",
        decimals = 18
    )

    private val baseCoin = CoinInfo(
        name = "Ethereum",
        symbol = "ETH",
        decimals = 18
    )

    // Ethereum Sepolia (chainId: 11155111)
    private val ethereumSepoliaTokens = mapOf(
        "USDC" to TokenInfo(
            name = "Sepolia USDC",
            symbol = "USDC",
            address = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
            decimals = 6
        )
    )

    // Base Sepolia (chainId: 84532)
    private val baseSepoliaTokens = mapOf(
        "USDC" to TokenInfo(
            name = "Base Sepolia USDC",
            symbol = "USDC",
            address = "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            decimals = 6
        )
    )

    // Ethereum Mainnet (chainId: 1)
    private val ethereumMainnetTokens = mapOf(
        "USDC" to TokenInfo(
            name = "USD Coin",
            symbol = "USDC",
            address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
            decimals = 6
        )
    )

    // Base Mainnet (chainId: 8453)
    private val baseMainnetTokens = mapOf(
        "USDC" to TokenInfo(
            name = "USD Coin",
            symbol = "USDC",
            address = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
            decimals = 6
        )
    )

    /**
     * chainId에 따라 사용 가능한 토큰 목록 반환
     */
    fun getTokensForChain(chainId: String): Map<String, TokenInfo> {
        return when (chainId) {
            "11155111" -> ethereumSepoliaTokens
            "84532" -> baseSepoliaTokens
            "1" -> ethereumMainnetTokens
            "8453" -> baseMainnetTokens
            else -> emptyMap()
        }
    }

    /**
     * chainId와 symbol로 특정 토큰 정보 반환. override 가 있으면 address 만 교체된 사본 반환.
     */
    fun getToken(chainId: String, symbol: String): TokenInfo? {
        val base = getTokensForChain(chainId)[symbol] ?: return null
        val overrideAddr = overrideAddress(chainId, symbol)
        return if (overrideAddr != null) base.copy(address = overrideAddr) else base
    }

    /**
     * chainId에서 사용 가능한 토큰 심볼 목록 반환
     */
    fun getAvailableTokenSymbols(chainId: String): List<String> {
        return getTokensForChain(chainId).keys.toList()
    }

    /**
     * chainId에 따라 네이티브 코인 정보 반환
     */
    fun getCoinForChain(chainId: String): CoinInfo? {
        return when (chainId) {
            "11155111" -> ethereumCoin   // Ethereum Sepolia
            "84532" -> baseCoin          // Base Sepolia
            "1" -> ethereumCoin          // Ethereum Mainnet
            "8453" -> baseCoin           // Base Mainnet
            else -> null
        }
    }

    /**
     * chainId 에 대응되는 공용 RPC 엔드포인트 URL.
     * 잔액 조회 / 읽기 전용 호출용 — 트랜잭션 전송은 SDK 가 별도 처리.
     */
    fun getRpcUrl(chainId: String): String? = when (chainId) {
        "11155111" -> "https://ethereum-sepolia-rpc.publicnode.com"
        "84532" -> "https://sepolia.base.org"
        "1" -> "https://ethereum-rpc.publicnode.com"
        "8453" -> "https://mainnet.base.org"
        else -> null
    }
}
