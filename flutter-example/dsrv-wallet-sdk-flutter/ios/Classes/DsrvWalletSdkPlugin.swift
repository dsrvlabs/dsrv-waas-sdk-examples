import Flutter
import UIKit
import Security
import dsrv_wallet_sdk_ios

/// Flutter ↔ native DSRVWallet 브릿지.
/// - 정방향: Dart invokeMethod → DSRVWallet 호출
/// - 역방향: AuthHandler.requestChallenge → Dart `onRequestChallenge`
public class DsrvWalletSdkPlugin: NSObject, FlutterPlugin {

    private let channel: FlutterMethodChannel

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.dsrv.wallet.sdk/api",
            binaryMessenger: registrar.messenger()
        )
        let instance = DsrvWalletSdkPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// FlutterError 는 Swift `Error` 를 conform 하지 않아 직접 throw 불가 — 내부 errno 로 변환 후
    /// `handle` 의 catch 에서 FlutterError 로 매핑한다.
    private struct PluginError: Error {
        let code: String
        let message: String
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        Task {
            do { try await dispatch(call.method, args, result) }
            catch let e as PluginError {
                result(FlutterError(code: e.code, message: e.message, details: nil))
            }
            catch {
                result(FlutterError(code: "INTERNAL",
                                    message: error.localizedDescription, details: nil))
            }
        }
    }

    /// Required string arg helper — Android `MethodCall.arg<T>()` 와 동치. missing 또는 빈 문자열을
    /// silent default ("") 로 coalesce 하지 않고 즉시 INVALID_ARGUMENT 로 surface 한다.
    private func requiredString(_ args: [String: Any], _ key: String) throws -> String {
        guard let v = args[key] as? String, !v.isEmpty else {
            throw PluginError(code: "INVALID_ARGUMENT",
                              message: "missing or empty arg: \(key)")
        }
        return v
    }

    private func dispatch(_ method: String, _ args: [String: Any], _ result: @escaping FlutterResult) async throws {
        switch method {
        case "initialize":
            let credential = UserCredential(
                type: credentialType(args["credentialType"] as? String),
                value: try requiredString(args, "credentialValue"),
                provider: args["provider"] as? String ?? ""
            )
            let r = await DSRVWallet.initialize(
                sdkId: try requiredString(args, "sdkId"),
                userCredential: credential,
                authHandler: DartAuthHandler(channel: channel),
                baseUrl: try requiredString(args, "baseUrl")
            )
            reply(r, result) { _ in nil }

        case "isInitialized":
            result(DSRVWallet.isInitialized)

        case "reset":
            await DSRVWallet.reset()
            result(nil)

        case "createAccount":
            let r = await DSRVWallet.createAccount(label: try requiredString(args, "label"))
            reply(r, result) { ["accountId": $0.accountId, "label": $0.label] }

        case "getAccountList":
            let r = await DSRVWallet.getAccountList()
            reply(r, result) { $0.map(self.accountMap) }

        case "getChainList":
            let r = await DSRVWallet.getChainList()
            reply(r, result) { $0.map(self.chainMap) }

        case "createAddress":
            let r = await DSRVWallet.createAddress(
                accountId: try requiredString(args, "accountId"),
                chainType: try requiredString(args, "chainType"),
                label: args["label"] as? String
            )
            reply(r, result) { ["publicKey": $0.publicKey, "address": $0.address] }

        case "transfer":
            let r = await DSRVWallet.transfer(
                address: try requiredString(args, "address"),
                chainId: try requiredString(args, "chainId"),
                asset: parseAsset(args["asset"] as? [String: Any] ?? [:]),
                recipient: try requiredString(args, "recipient"),
                amount: try requiredString(args, "amount")
            )
            reply(r, result) { ["txHash": $0.txHash] }

        case "buildTx":
            let r = await DSRVWallet.buildTx(
                address: try requiredString(args, "address"),
                chainId: try requiredString(args, "chainId"),
                asset: parseAsset(args["asset"] as? [String: Any] ?? [:]),
                recipient: try requiredString(args, "recipient"),
                amount: try requiredString(args, "amount")
            )
            reply(r, result) {
                ["txId": $0.txId, "signId": $0.signId, "messageHash": $0.messageHash, "type": $0.type]
            }

        case "broadcastTx":
            let r = await DSRVWallet.broadcastTx(
                address: try requiredString(args, "address"),
                txId: try requiredString(args, "txId")
            )
            reply(r, result) { ["txHash": $0.txHash] }

        case "sign":
            let r = await DSRVWallet.sign(
                address: try requiredString(args, "address"),
                hashedMessage: try requiredString(args, "hashedMessage"),
                signId: try requiredString(args, "signId"),
                messageType: try requiredString(args, "messageType")
            )
            reply(r, result) { ["r": $0.r, "s": $0.s, "v": $0.v] }

        case "delegate":
            let r = await DSRVWallet.delegate(address: try requiredString(args, "address"))
            reply(r, result) { $0.map(self.chainTxResultMap) }

        case "revoke":
            let r = await DSRVWallet.revoke(address: try requiredString(args, "address"))
            reply(r, result) { $0.map(self.chainTxResultMap) }

        case "approve":
            let r = await DSRVWallet.approve(address: try requiredString(args, "address"))
            reply(r, result) { $0.map(self.chainTxResultMap) }

        case "backup":
            let r = await DSRVWallet.backup()
            reply(r, result) { _ in nil }

        case "restore":
            let r = await DSRVWallet.restore()
            reply(r, result) { $0.map(self.restoredMap) }

        case "clearDeviceKeyForDebug":
            // 저장된 App Attest keyId 삭제 → 다음 init 시 새 키 생성·재attest.
            // (keychain 은 앱 삭제로도 안 지워지므로 디버그용으로 직접 제거)
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.dsrv.wallet.sdk.attest-key-id",
            ] as CFDictionary)
            result(nil)

        case "dumpBackupForDebug":
            result(DSRVWallet.dumpBackupForDebug())

        case "clearBackupForDebug":
            DSRVWallet.clearBackupForDebug()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - WalletResult → FlutterResult

    private func reply<T>(_ r: WalletResult<T>, _ result: @escaping FlutterResult, _ transform: (T) -> Any?) {
        switch r {
        case .success(let data): result(transform(data))
        case .failure(let error):
            result(FlutterError(code: "\(error.code)", message: error.description, details: nil))
        }
    }

    // MARK: - 직렬화 helper

    private func parseAsset(_ map: [String: Any]) -> TransferAsset {
        if (map["type"] as? String) == "erc20", let token = map["tokenAddress"] as? String {
            return .erc20(tokenAddress: token)
        }
        return .native
    }

    private func credentialType(_ wire: String?) -> CredentialType {
        switch wire {
        case "OAUTH_TOKEN": return .oauthToken
        case "IDP_TOKEN": return .idpToken
        default: return .userId
        }
    }

    private func accountMap(_ a: AccountInfo) -> [String: Any?] {
        return [
            "accountId": a.accountId,
            "label": a.label,
            "addresses": a.addresses.map { [
                "accountId": $0.accountId,
                "addressId": $0.addressId,
                "address": $0.address,
                "publicKey": $0.publicKey,
                "label": $0.label,
                "chainType": $0.chainType,
            ] },
        ]
    }

    private func chainMap(_ c: ChainInfo) -> [String: Any] {
        return ["chainId": c.chainId, "name": c.name, "chainType": c.chainType, "networkType": c.networkType]
    }

    private func restoredMap(_ r: RestoredKey) -> [String: Any?] {
        return ["address": r.address, "success": r.success, "error": r.error]
    }

    private func chainTxResultMap(_ r: ChainTxResult) -> [String: Any?] {
        return [
            "chainId": r.chainId,
            "outcome": r.outcome,
            "txHash": r.txHash,
            "errorMessage": r.errorMessage,
        ]
    }
}

/// AuthHandler.requestChallenge 를 Dart 로 역방향 위임.
final class DartAuthHandler: AuthHandler {
    private let channel: FlutterMethodChannel
    init(channel: FlutterMethodChannel) { self.channel = channel }

    func requestChallenge(request: ChallengeRequest) async -> ChallengeResult {
        let reqMap: [String: Any] = [
            "sdkId": request.sdkId,
            "appId": request.appId,
            "credentialType": request.userCredential.type.rawValue,
            "credentialValue": request.userCredential.value,
            "provider": request.userCredential.provider,
            "deviceInfo": [
                "keyId": request.deviceInfo.keyId as Any,
                "publicKey": request.deviceInfo.publicKey as Any,
                "model": request.deviceInfo.model,
                "osVersion": request.deviceInfo.osVersion,
                "isVirtual": request.deviceInfo.isVirtual,
                "attestationObject": request.deviceInfo.attestationObject as Any,
                "platform": "IOS",
            ],
        ]

        let reply: Any? = await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                self.channel.invokeMethod("onRequestChallenge", arguments: reqMap) { res in
                    cont.resume(returning: res)
                }
            }
        }

        guard let map = reply as? [String: Any], (map["success"] as? Bool) == true,
              let challenge = map["challenge"] as? String else {
            let err = (reply as? [String: Any])?["error"] as? String ?? "Challenge failed"
            return .failure(error: err)
        }
        return .success(challenge: challenge)
    }
}
