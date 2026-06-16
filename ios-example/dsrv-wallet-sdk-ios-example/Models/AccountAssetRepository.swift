import Foundation

/// customer-backend `GET /sdk/asset/accounts/{accountId}` 호출 client —
/// WaaS 계정 자산 목록(계정의 모든 주소 잔고를 chain·asset 단위로 합산)을 조회한다. RPC 직접 호출(`BalanceClient`) 대체.
///
/// customer-backend 가 자체 server-key(`X_API_KEY`)로 WaaS 의
/// `GET /api/v1/embedded-wallets/ncw/accounts/{accountId}/assets` 를 호출하므로 example 은 user token 을
/// 보내지 않는다 (`TransactionHistoryRepository`/`AssetValueRepository` 와 동일 패턴).
/// userId·addressId 불필요 — projectId(passport) + accountId 로 스코핑.
struct AccountAssetRepository {
    let backendUrl: String

    func getAccountAssets(accountId: String) async throws -> AccountAssetsResponse {
        let path = "\(backendUrl)/sdk/asset/accounts/\(accountId)"
        let response = try await HttpHelper.get(url: path, queryItems: [], timeout: 15)
        guard let data = response.data(using: .utf8) else {
            throw HttpHelper.HttpError.invalidResponse
        }
        return try JSONDecoder().decode(AccountAssetsResponse.self, from: data)
    }
}

/// `GET /sdk/asset/accounts/{accountId}` response item — WaaS AccountAssetInfo 와 1:1.
struct AccountAssetItem: Decodable, Sendable {
    let chainId: String
    /// 체인 계열 (EVM / SVM).
    let chainType: String
    /// 토큰 컨트랙트 주소. native 코인은 null.
    let contractAddress: String?
    /// raw smallest-unit 잔고 (wei 등, decimals 미적용). 정밀도 보존 위해 string.
    let balance: String
    /// WaaS 가 제공할 때만 존재하는 자산 심볼(예: "ETH","USDC"). 없으면 앱이 price-hub 로 보완.
    let symbol: String?
}

struct AccountAssetsPagination: Decodable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
}

struct AccountAssetsResponse: Decodable, Sendable {
    let items: [AccountAssetItem]
    let pagination: AccountAssetsPagination
}

/// 드롭다운 한 줄에 필요한 자산 표시 정보 — WaaS 자산(raw balance + 가능 시 symbol) + price-hub
/// 메타(없는 symbol/decimals 보완)를 합쳐 만든다.
struct AssetRow: Identifiable, Equatable, Sendable {
    let chainId: String
    /// native 코인은 nil.
    let contractAddress: String?
    /// raw smallest-unit 잔고 (decimals 미적용).
    let rawBalance: String
    let symbol: String
    let name: String
    let decimals: Int
    /// decimals 적용된 사람이 읽는 잔고 ("1.5").
    let humanizedBalance: String

    /// (chainId, contractAddress) 조합이 자산 고유키. native 는 "native".
    var id: String { "\(chainId):\(contractAddress?.lowercased() ?? "native")" }
    var isNative: Bool { contractAddress?.isEmpty ?? true }
    /// 드롭다운 라벨: 심볼만("ETH"). 잔액은 별도 잔액 row 에 표시.
    var displayLabel: String { symbol }
}
