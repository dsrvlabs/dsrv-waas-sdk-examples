import Foundation

/// customer-backend `/sdk/transfer/build-hash`, `/sdk/transfer/broadcast` 호출 client.
///
/// customer-backend 가 자체 server-key (`X_API_KEY`) 로 WaaS 와 통신하므로 example 은
/// user token 을 보내지 않는다. sign 단계만 SDK 의 `DSRVWallet.sign` 으로 직접 수행.
struct TransferRepository {
    let backendUrl: String

    func buildHash(_ request: BuildTransferRequest) async throws -> BuildTransferResponse {
        let body = request.toJsonBody()
        let response = try await HttpHelper.post(
            url: "\(backendUrl)/sdk/transfer/build-hash",
            jsonBody: body
        )
        guard let data = response.data(using: .utf8) else {
            throw HttpHelper.HttpError.invalidResponse
        }
        return try JSONDecoder().decode(BuildTransferResponse.self, from: data)
    }

    func broadcast(_ request: BroadcastTransferRequest) async throws -> BroadcastTransferResponse {
        let response = try await HttpHelper.post(
            url: "\(backendUrl)/sdk/transfer/broadcast",
            jsonBody: request.toJsonBody()
        )
        guard let data = response.data(using: .utf8) else {
            throw HttpHelper.HttpError.invalidResponse
        }
        return try JSONDecoder().decode(BroadcastTransferResponse.self, from: data)
    }
}

/// `POST /sdk/transfer/build-hash` request.
struct BuildTransferRequest {
    let fromAddress: String
    let toAddress: String
    /// wei (base units, 정수 문자열).
    let amount: String
    /// EVM chainId (문자열).
    let chainId: String
    /// ERC-20 컨트랙트 주소 — nil 이면 native 전송.
    let contractAddress: String?

    func toJsonBody() -> [String: Any] {
        var body: [String: Any] = [
            "fromAddress": fromAddress,
            "toAddress": toAddress,
            "amount": amount,
            "chainId": chainId,
        ]
        if let contractAddress = contractAddress {
            body["contractAddress"] = contractAddress
        }
        return body
    }
}

/// `POST /sdk/transfer/build-hash` response.
struct BuildTransferResponse: Decodable {
    /// broadcast path 파라미터 (BTX-...).
    let txId: String
    /// MPC sign 의 id 슬롯에 그대로 넘김 — TRANSACTION 이면 TX-..., CONTRACT_CALL 이면 EXE-...
    let signId: String
    /// 서명 대상 keccak256 hash (0x-hex).
    let messageHash: String
    /// 서명 대상 message 종류 — TRANSACTION | CONTRACT_CALL.
    let type: String
}

/// `POST /sdk/transfer/broadcast` request.
struct BroadcastTransferRequest {
    let txId: String

    func toJsonBody() -> [String: Any] {
        ["txId": txId]
    }
}

/// `POST /sdk/transfer/broadcast` response.
///
/// [txHash] 는 EIP-7702 bundler 경로일 때 응답 시점에 아직 발급 안 됨 (null).
/// 이 때 [status] == "SIGNED" 이며 bundler 가 별도 시점에 onchain 전송 → 후속 polling 필요.
/// 일반 EOA 경로는 즉시 [txHash] 가 채워지고 [status] == "BROADCAST".
struct BroadcastTransferResponse: Decodable {
    let txHash: String?
    let status: String
    let batchTxId: String
}
