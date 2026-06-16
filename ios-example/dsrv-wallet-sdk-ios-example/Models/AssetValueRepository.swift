import Foundation

/// customer-backend `GET /sdk/asset/by-chain/latest-value` 호출 client — 자산 가치(법정통화 환산) 조회.
///
/// customer-backend 가 자체 server-key 로 price-hub 를 호출하므로 example 은 user token 을 보내지 않는다
/// (`TransactionHistoryRepository` 와 동일 패턴).
struct AssetValueRepository {
    let backendUrl: String

    /// - Parameters:
    ///   - chainId: 조회 대상 체인 식별자 (필수)
    ///   - contractAddress: ERC-20 토큰 주소. 네이티브 코인(ETH) 은 nil/빈 문자열 → 쿼리에서 제외
    ///   - amount: 사람이 읽는 십진 표기(예 "0.5"). 보유량 환산이 필요할 때만 전달
    ///   - currency: 환산 통화 (KRW 고정)
    func getLatestValue(
        chainId: String,
        contractAddress: String?,
        amount: String?,
        currency: String = "KRW"
    ) async throws -> AssetLatestValueResponse {
        var queryItems = [
            URLQueryItem(name: "chainId", value: chainId),
            URLQueryItem(name: "currency", value: currency),
        ]
        if let contractAddress, !contractAddress.isEmpty {
            queryItems.append(URLQueryItem(name: "contractAddress", value: contractAddress))
        }
        if let amount {
            queryItems.append(URLQueryItem(name: "amount", value: amount))
        }
        let response = try await HttpHelper.get(
            url: "\(backendUrl)/sdk/asset/by-chain/latest-value",
            queryItems: queryItems,
            timeout: 15
        )
        guard let data = response.data(using: .utf8) else {
            throw HttpHelper.HttpError.invalidResponse
        }
        return try JSONDecoder().decode(AssetLatestValueResponse.self, from: data)
    }
}

/// `GET /sdk/asset/by-chain/latest-value` response 의 asset 메타.
struct AssetLatestValueAsset: Decodable {
    let chainId: String
    let chainName: String
    let contractAddress: String?
    let symbol: String
    let name: String
    let tokenStandard: String?
    /// native 토큰은 price-hub 가 null 로 내려줄 수 있으므로 Optional — non-optional 이면 디코딩 자체가
    /// throw 되어 KRW 환산이 통째로 실패한다 (Android `Int = 0` / Flutter `int?` 와 동일 취급).
    let decimals: Int?
}

/// 단가 정보. value 는 price-hub 가 BigDecimal 을 직렬화한 값으로, Double 정밀도 손실을 피하기 위해
/// 문자열로 보존한다 (Android/Flutter 와 동일). JSON number 로 도착해도 문자열로 정규화.
struct AssetLatestValuePrice: Decodable {
    let currency: String
    let value: String
    let fetchedAt: String
    let source: String

    private enum CodingKeys: String, CodingKey { case currency, value, fetchedAt, source }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currency = try c.decode(String.self, forKey: .currency)
        value = try c.decodeAmountString(forKey: .value)
        fetchedAt = try c.decode(String.self, forKey: .fetchedAt)
        source = try c.decode(String.self, forKey: .source)
    }
}

/// 보유량 환산. amount 가 0 이면 응답에서 통째로 빠지므로 Optional.
/// amount/totalValue 는 BigDecimal 직렬화값으로, Double 정밀도 손실을 피해 문자열로 보존한다.
struct AssetLatestValueHoldings: Decodable {
    let amount: String
    let totalValue: String

    private enum CodingKeys: String, CodingKey { case amount, totalValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = try c.decodeAmountString(forKey: .amount)
        totalValue = try c.decodeAmountString(forKey: .totalValue)
    }
}

private extension KeyedDecodingContainer {
    /// JSON number 또는 string 으로 도착하는 금액 필드를 문자열로 디코드 — Double 정밀도 손실 방지.
    func decodeAmountString(forKey key: Key) throws -> String {
        if let s = try? decode(String.self, forKey: key) { return s }
        let d = try decode(Decimal.self, forKey: key)
        return NSDecimalNumber(decimal: d).stringValue
    }
}

/// `GET /sdk/asset/by-chain/latest-value` response.
struct AssetLatestValueResponse: Decodable {
    let asset: AssetLatestValueAsset
    let price: AssetLatestValuePrice
    let holdings: AssetLatestValueHoldings?
}
