import Foundation

/// customer-backend `POST /payments` 호출 client.
///
/// customer-backend 가 내부에서 stablecoin Payments quote → paymentDigest 서명(고객사 PK) → execute
/// 를 한 번에 처리. 클라이언트는 paymentDigest 서명을 직접 하지 않는다.
struct PaymentRepository {
    let backendUrl: String

    func pay(_ request: PaymentRequest) async throws -> PaymentResponse {
        let response = try await HttpHelper.post(
            url: "\(backendUrl)/payments",
            jsonBody: request.toJsonBody()
        )
        guard let data = response.data(using: .utf8) else {
            throw HttpHelper.HttpError.invalidResponse
        }
        return try JSONDecoder().decode(PaymentResponse.self, from: data)
    }
}

/// `POST /payments` request — Topup 결제.
struct PaymentRequest {
    let sourceUserId: String
    let chainId: Int
    let token: String
    let from: String
    let to: String
    /// humanized 문자열 (예: "1.5"). 단위 변환(wei)은 stablecoin Payments 가 담당.
    let amount: String
    /// onchainPaymentType — 0 = 일반 결제.
    let paymentType: Int

    func toJsonBody() -> [String: Any] {
        [
            "sourceUserId": sourceUserId,
            "chainId": chainId,
            "token": token,
            "from": from,
            "to": to,
            "amount": amount,
            "paymentType": paymentType,
        ]
    }
}

/// `POST /payments` response — stablecoin Payments transaction 결과.
///
/// `txHash` 는 EIP-7702 bundler 경로 또는 비동기 broadcast 일 때 응답 시점에
/// 아직 발급 안 될 수 있어 nullable. status 가 SIGNED/PENDING 이면 후속 polling 필요.
struct PaymentResponse: Decodable {
    let transactionId: String
    let paymentUuid: String
    let status: String
    let txHash: String?
    let submittedAt: String?
}
