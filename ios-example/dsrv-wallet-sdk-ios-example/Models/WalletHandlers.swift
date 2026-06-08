//
//  WalletHandlers.swift
//  dsrv-wallet-sdk-ios-example
//
//  AuthHandler implementation for customer backend communication.
//  Follows the Delegate pattern used by Fireblocks, Web3Auth, Cobo, etc.
//

import Foundation
import dsrv_wallet_sdk_ios

/// AuthHandler implementation that delegates authentication to customer backend.
/// Follows the Delegate pattern - SDK calls these methods, app handles backend communication.
class MyAuthHandler: AuthHandler {
    private let backendUrl: String

    init(backendUrl: String) {
        self.backendUrl = backendUrl
    }

    func requestChallenge(request: ChallengeRequest) async -> ChallengeResult {
        print("MyAuthHandler: requestChallenge(sdkId: \(request.sdkId), appId: \(request.appId)) - POST \(backendUrl)/sdk/registration")
        do {
            let body: [String: Any] = [
                "sdkId": request.sdkId,
                "appId": request.appId,
                "userCredential": [
                    "type": request.userCredential.type.rawValue,
                    "value": request.userCredential.value,
                    "provider": request.userCredential.provider
                ],
                "deviceInfo": [
                    "platform": request.deviceInfo.platform,
                    "publicKey": request.deviceInfo.publicKey as Any,
                    "model": request.deviceInfo.model,
                    "osVersion": request.deviceInfo.osVersion,
                    "isVirtual": request.deviceInfo.isVirtual,
                    "attestationObject": request.deviceInfo.attestationObject as Any
                ]
            ]

            let response = try await HttpHelper.post(
                url: "\(backendUrl)/sdk/registration",
                jsonBody: body
            )
            print("MyAuthHandler: registration response: \(response)")

            guard let data = response.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("MyAuthHandler: requestChallenge() - Failed to parse JSON response")
                return .failure(error: "Failed to parse response")
            }

            guard let payload = json["data"] as? [String: Any],
                  let challenge = payload["challenge"] as? String, !challenge.isEmpty else {
                print("MyAuthHandler: requestChallenge() - Challenge is empty")
                return .failure(error: "Challenge request failed")
            }

            print("MyAuthHandler: requestChallenge() - Success, challenge: \(challenge)")
            return .success(challenge: challenge)
        } catch let error as HttpHelper.HttpError {
            switch error {
            case .httpError(let statusCode, let body):
                print("MyAuthHandler: requestChallenge() - HTTP \(statusCode): \(body)")
                return .failure(error: "HTTP \(statusCode): \(body)")
            default:
                print("MyAuthHandler: requestChallenge() - Error: \(error)")
                return .failure(error: error.localizedDescription)
            }
        } catch {
            print("MyAuthHandler: requestChallenge() - Error: \(error)")
            return .failure(error: error.localizedDescription)
        }
    }
}
