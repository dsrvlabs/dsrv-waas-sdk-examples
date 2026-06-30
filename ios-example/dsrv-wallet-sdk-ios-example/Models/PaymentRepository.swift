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

/// `POST /payments` 의 한쪽 endpoint (출금=source / 수령=destination).
///
/// cross-chain: source 와 destination 이 서로 다른 체인일 수 있어 chain/token/주소를
/// endpoint 단위로 받는다. 같은 USDC 라도 컨트랙트 주소는 체인마다 달라 `tokenAddress` 도 endpoint 별.
struct PaymentEndpoint {
    let chainId: Int
    let tokenAddress: String
    /// source = payer(NCW) 주소, destination = 수령자 주소.
    let address: String

    func toJson() -> [String: Any] {
        [
            "chainId": chainId,
            "tokenAddress": tokenAddress,
            "address": address,
        ]
    }
}

/// `POST /payments` request — Topup 결제 (cross-chain).
///
/// 출금(`source`) / 수령(`destination`) 을 분리해 보낸다. same-chain 결제는 두 endpoint 의
/// chainId/tokenAddress 를 동일하게 보내면 된다.
struct PaymentRequest {
    let sourceUserId: String
    let source: PaymentEndpoint
    let destination: PaymentEndpoint
    /// humanized 문자열 (예: "1.5"). 단위 변환(wei)은 stablecoin Payments 가 담당.
    let amount: String
    /// onchainPaymentType — 0 = 일반 결제.
    let paymentType: Int

    func toJsonBody() -> [String: Any] {
        [
            "sourceUserId": sourceUserId,
            "source": source.toJson(),
            "destination": destination.toJson(),
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
