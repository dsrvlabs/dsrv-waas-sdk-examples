import Foundation

/// customer-backend `GET /sdk/transactions` 호출 client — transaction history 조회.
///
/// customer-backend 가 자체 server-key (`X_API_KEY`) 로 WaaS 의
/// `GET /api/v1/embedded-wallets/ncw/transactions` (fromAddress 필터) 를 호출하므로
/// example 은 user token 을 보내지 않는다 (`TransferRepository` 와 동일 패턴).
struct TransactionHistoryRepository {
    let backendUrl: String

    /// - Parameters:
    ///   - address: 조회 대상 지갑 주소 (fromAddress 필터)
    ///   - page: 1-base 페이지 번호
    ///   - limit: 페이지당 항목 수 (WaaS 최대 100)
    func getTransactions(
        address: String,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> TransactionHistoryResponse {
        let queryItems = [
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        let response = try await HttpHelper.get(
            url: "\(backendUrl)/sdk/transactions",
            queryItems: queryItems
        )
        guard let data = response.data(using: .utf8) else {
            throw HttpHelper.HttpError.invalidResponse
        }
        return try JSONDecoder().decode(TransactionHistoryResponse.self, from: data)
    }
}

/// `GET /sdk/transactions` response item — WaaS EwTransactionInfo 와 1:1.
struct TransactionHistoryItem: Decodable, Identifiable {
    /// WaaS 트랜잭션 비즈니스 키 (TX-...).
    let transactionId: String
    let chainId: String
    /// 체인 계열 식별자 (EVM 등).
    let chainType: String
    /// 트랜잭션 상태 그룹 (PENDING / COMPLETED / FAILED 등).
    let status: String
    let fromAddress: String
    let toAddress: String?
    /// onchain hash — 브로드캐스트 전이면 nil.
    let txHash: String?
    /// 트랜잭션 종류 (transfer 등).
    let method: String?
    /// ISO 8601 생성 시각.
    let createdAt: String

    var id: String { transactionId }
}

struct TransactionHistoryPagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int
}

/// `GET /sdk/transactions` response.
struct TransactionHistoryResponse: Decodable {
    let items: [TransactionHistoryItem]
    let pagination: TransactionHistoryPagination
}
