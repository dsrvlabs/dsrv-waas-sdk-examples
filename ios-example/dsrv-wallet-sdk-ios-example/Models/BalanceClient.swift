import Foundation

/// 읽기 전용 JSON-RPC 클라이언트 — 잔액 조회용. RPC URL 은 TokenConfig.getRpcUrl 매핑.
struct BalanceClient {

    enum BalanceError: Error, LocalizedError {
        case rpcUrlMissing(String)
        case httpError(Int, String)
        case rpcError(String)
        case malformedResponse(String)

        var errorDescription: String? {
            switch self {
            case .rpcUrlMissing(let id): return "chainId=\(id) 의 RPC URL 이 정의되지 않았습니다"
            case .httpError(let code, let body): return "HTTP \(code): \(body)"
            case .rpcError(let msg): return "RPC error: \(msg)"
            case .malformedResponse(let body): return "malformed response: \(body)"
            }
        }
    }

    /// 네이티브 코인 잔액 (wei, 정수 decimal 문자열).
    func getNativeBalance(chainId: String, address: String) async throws -> String {
        guard let url = TokenConfig.getRpcUrl(chainId) else { throw BalanceError.rpcUrlMissing(chainId) }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [address, "latest"],
            "id": 1
        ]
        return try await callRpc(url: url, payload: payload)
    }

    /// ERC-20 잔액 (base units, 정수 decimal 문자열).
    func getErc20Balance(chainId: String, tokenAddress: String, ownerAddress: String) async throws -> String {
        guard let url = TokenConfig.getRpcUrl(chainId) else { throw BalanceError.rpcUrlMissing(chainId) }
        var owner = ownerAddress
        if owner.hasPrefix("0x") { owner = String(owner.dropFirst(2)) }
        owner = owner.lowercased()
        owner = String(repeating: "0", count: max(0, 64 - owner.count)) + owner
        let data = "0x70a08231" + owner
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [["to": tokenAddress, "data": data], "latest"],
            "id": 1
        ]
        return try await callRpc(url: url, payload: payload)
    }

    private func callRpc(url: String, payload: [String: Any]) async throws -> String {
        guard let endpoint = URL(string: url) else { throw BalanceError.rpcUrlMissing(url) }
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let bodyStr = String(data: data, encoding: .utf8) ?? ""

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw BalanceError.httpError(http.statusCode, bodyStr)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BalanceError.malformedResponse(bodyStr)
        }
        if let errObj = json["error"] as? [String: Any] {
            let msg = errObj["message"] as? String ?? bodyStr
            throw BalanceError.rpcError(msg)
        }
        guard let hex = json["result"] as? String else {
            throw BalanceError.malformedResponse(bodyStr)
        }
        return hexToDecimalString(hex)
    }
}
