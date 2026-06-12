package com.dsrv.wallet.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.fragment.app.FragmentActivity
import com.dsrv.wallet.sdk.AuthHandler
import com.dsrv.wallet.sdk.ChallengeRequest
import com.dsrv.wallet.sdk.ChallengeResult
import com.dsrv.wallet.sdk.CredentialType
import com.dsrv.wallet.sdk.DSRVWallet
import com.dsrv.wallet.sdk.TransferAsset
import com.dsrv.wallet.sdk.UserCredential
import com.dsrv.wallet.sdk.WalletResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlin.coroutines.resume

/**
 * Flutter ↔ native DSRVWallet 브릿지.
 * - 정방향: Dart invokeMethod → DSRVWallet 호출
 * - 역방향: AuthHandler.requestChallenge → Dart `onRequestChallenge`
 */
class DsrvWalletSdkPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var activity: FragmentActivity? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.dsrv.wallet.sdk/api")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? FragmentActivity
    }

    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) {
        activity = b.activity as? FragmentActivity
    }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }

    override fun onMethodCall(call: MethodCall, result: Result) {
        scope.launch {
            try {
                handle(call, result)
            } catch (e: Exception) {
                result.error("9001", e.message ?: "Unknown", null)
            }
        }
    }

    private suspend fun handle(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val sdkId = call.arg<String>("sdkId")
                val credential = UserCredential(
                    type = CredentialType.valueOf(
                        (call.argument<String>("credentialType") ?: "USER_ID")
                            .let { wireToEnum(it) }
                    ),
                    value = call.arg("credentialValue"),
                    provider = call.argument<String>("provider") ?: ""
                )
                val r = DSRVWallet.initialize(
                    appContext, sdkId, credential, dartAuthHandler(),
                    baseUrl = call.arg("baseUrl"),
                    cloudProjectNumber = call.argument<Number>("cloudProjectNumber")?.toLong()
                )
                r.reply(result) { null }
            }

            "isInitialized" -> result.success(DSRVWallet.isInitialized)

            "reset" -> {
                DSRVWallet.reset()
                result.success(null)
            }

            "createAccount" -> DSRVWallet.createAccount(call.arg("label"))
                .reply(result) { mapOf("accountId" to it.accountId, "label" to it.label) }

            "getAccountList" -> DSRVWallet.getAccountList()
                .reply(result) { list -> list.map { accountMap(it) } }

            "getChainList" -> DSRVWallet.getChainList()
                .reply(result) { list -> list.map { chainMap(it) } }

            "createAddress" -> DSRVWallet.createAddress(
                accountId = call.arg("accountId"),
                chainType = call.arg("chainType"),
                label = call.argument<String>("label")
            ).reply(result) { mapOf("publicKey" to it.publicKey, "address" to it.address) }

            "transfer" -> DSRVWallet.transfer(
                address = call.arg("address"),
                chainId = call.arg("chainId"),
                asset = parseAsset(call.arg("asset")),
                recipient = call.arg("recipient"),
                amount = call.arg("amount")
            ).reply(result) { mapOf("txHash" to it.txHash) }

            "buildTx" -> DSRVWallet.buildTx(
                address = call.arg("address"),
                chainId = call.arg("chainId"),
                asset = parseAsset(call.arg("asset")),
                recipient = call.arg("recipient"),
                amount = call.arg("amount")
            ).reply(result) {
                mapOf(
                    "txId" to it.txId,
                    "signId" to it.signId,
                    "messageHash" to it.messageHash,
                    "type" to it.type
                )
            }

            "broadcastTx" -> DSRVWallet.broadcastTx(
                address = call.arg("address"),
                txId = call.arg("txId")
            ).reply(result) { mapOf("txHash" to it.txHash) }

            "sign" -> DSRVWallet.sign(
                address = call.arg("address"),
                hashedMessage = call.arg("hashedMessage"),
                signId = call.arg("signId"),
                messageType = call.arg("messageType")
            ).reply(result) { mapOf("r" to it.r, "s" to it.s, "v" to it.v) }

            "delegate" -> DSRVWallet.delegate(call.arg("address"))
                .reply(result) { list -> list.map(::chainTxResultMap) }

            "revoke" -> DSRVWallet.revoke(call.arg("address"))
                .reply(result) { list -> list.map(::chainTxResultMap) }

            "approve" -> DSRVWallet.approve(call.arg("address"), call.arg("amount"))
                .reply(result) { list -> list.map(::chainTxResultMap) }

            "backup" -> {
                val act = activity ?: return result.error(
                    "4201", "FragmentActivity 없음 (FlutterFragmentActivity 필요)", null)
                DSRVWallet.backup(act).reply(result) { null }
            }

            "restore" -> {
                val act = activity ?: return result.error(
                    "4202", "FragmentActivity 없음 (FlutterFragmentActivity 필요)", null)
                DSRVWallet.restore(act)
                    .reply(result) { list -> list.map { restoredMap(it) } }
            }

            // Android 는 Play Integrity(stateless)라 저장된 attest 키가 없음 → no-op
            "clearDeviceKeyForDebug" -> result.success(null)

            "dumpBackupForDebug" -> result.success(DSRVWallet.dumpBlockStoreForDebug())
            "clearBackupForDebug" -> { DSRVWallet.clearBackupForDebug(); result.success(null) }

            else -> result.notImplemented()
        }
    }

    // MARK: - AuthHandler 역방향 콜백

    private fun dartAuthHandler() = object : AuthHandler {
        override suspend fun requestChallenge(request: ChallengeRequest): ChallengeResult {
            val reply = invokeDart("onRequestChallenge", challengeReqMap(request))
            val map = reply as? Map<*, *>
                ?: return ChallengeResult.Failure("Invalid challenge reply")
            val success = map["success"] as? Boolean ?: false
            return if (success) {
                ChallengeResult.Success(map["challenge"] as? String ?: "")
            } else {
                ChallengeResult.Failure(map["error"] as? String ?: "Challenge failed")
            }
        }
    }

    /** native → Dart 호출을 메인 스레드에서 수행하고 suspend 로 결과 대기. */
    private suspend fun invokeDart(method: String, args: Any?): Any? =
        suspendCancellableCoroutine { cont ->
            mainHandler.post {
                channel.invokeMethod(method, args, object : Result {
                    override fun success(r: Any?) { if (cont.isActive) cont.resume(r) }
                    override fun error(c: String, m: String?, d: Any?) {
                        if (cont.isActive) cont.resume(mapOf("success" to false, "error" to m))
                    }
                    override fun notImplemented() {
                        if (cont.isActive) cont.resume(mapOf("success" to false, "error" to "notImplemented"))
                    }
                })
            }
        }

    // MARK: - 직렬화 helper

    private fun <T> WalletResult<T>.reply(result: Result, transform: (T) -> Any?) {
        when (this) {
            is WalletResult.Success -> result.success(transform(data))
            is WalletResult.Failure -> result.error(error.code.toString(), error.message, null)
        }
    }

    private fun parseAsset(map: Map<String, Any?>): TransferAsset =
        when (map["type"]) {
            "erc20" -> TransferAsset.Erc20(map["tokenAddress"] as String)
            else -> TransferAsset.Native
        }

    private fun accountMap(a: com.dsrv.wallet.sdk.AccountInfo) = mapOf(
        "accountId" to a.accountId,
        "label" to a.label,
        "addresses" to a.addresses.map {
            mapOf(
                "accountId" to it.accountId,
                "addressId" to it.addressId,
                "address" to it.address,
                "publicKey" to it.publicKey,
                "label" to it.label,
                "chainType" to it.chainType
            )
        }
    )

    private fun chainMap(c: com.dsrv.wallet.sdk.ChainInfo) = mapOf(
        "chainId" to c.chainId, "name" to c.name,
        "chainType" to c.chainType, "networkType" to c.networkType
    )

    private fun restoredMap(r: com.dsrv.wallet.sdk.RestoredKey) =
        mapOf("address" to r.address, "success" to r.success, "error" to r.error)

    private fun chainTxResultMap(r: com.dsrv.wallet.sdk.ChainTxResult) = mapOf(
        "chainId" to r.chainId,
        "outcome" to r.outcome,
        "txHash" to r.txHash,
        "errorMessage" to r.errorMessage,
    )

    private fun challengeReqMap(r: ChallengeRequest) = mapOf(
        "sdkId" to r.sdkId,
        "appId" to r.appId,
        "credentialType" to r.userCredential.type.name.let { enumToWire(it) },
        "credentialValue" to r.userCredential.value,
        "provider" to r.userCredential.provider,
        "deviceInfo" to mapOf(
            "publicKey" to r.deviceInfo.publicKey,
            "model" to r.deviceInfo.model,
            "osVersion" to r.deviceInfo.osVersion,
            "isVirtual" to r.deviceInfo.isVirtual,
            "platform" to "ANDROID"
        )
    )

    private fun wireToEnum(wire: String) = when (wire) {
        "USER_ID" -> "USER_ID"
        "OAUTH_TOKEN" -> "OAUTH_TOKEN"
        "IDP_TOKEN" -> "IDP_TOKEN"
        else -> "USER_ID"
    }

    private fun enumToWire(name: String) = name // CredentialType.name 이 곧 wire 값

    private inline fun <reified T> MethodCall.arg(key: String): T =
        argument<T>(key) ?: throw IllegalArgumentException("missing arg: $key")
}
