package com.dsrv.wallet.example.wallet.model

import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * customer-backend `/sdk/transfer/build-hash`, `/sdk/transfer/broadcast` 호출 client.
 *
 * customer-backend 가 자체 server-key (X_API_KEY) 로 WaaS 와 통신하므로 example 은 user
 * token 을 보내지 않는다. sign 단계만 SDK 의 [com.dsrv.wallet.sdk.DSRVWallet.sign] 으로 직접 수행.
 */
class TransferRepository(private val backendUrl: String) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    suspend fun buildHash(request: BuildTransferRequest): BuildTransferResponse =
        post("/sdk/transfer/build-hash", request, BuildTransferResponse::class.java)

    suspend fun broadcast(request: BroadcastTransferRequest): BroadcastTransferResponse =
        post("/sdk/transfer/broadcast", request, BroadcastTransferResponse::class.java)

    private suspend fun <T> post(path: String, body: Any, type: Class<T>): T =
        withContext(Dispatchers.IO) {
            val req = Request.Builder()
                .url("$backendUrl$path")
                .post(gson.toJson(body).toRequestBody("application/json".toMediaType()))
                .build()
            client.newCall(req).execute().use { resp ->
                val text = resp.body?.string().orEmpty()
                if (!resp.isSuccessful) {
                    throw RuntimeException("$path [${resp.code}]: $text")
                }
                gson.fromJson(text, type)
            }
        }
}

/** customer-backend `POST /sdk/transfer/build-hash` request. */
data class BuildTransferRequest(
    val fromAddress: String,
    val toAddress: String,
    /** base units (정수 문자열) — 네이티브 ETH 는 wei, ERC-20 은 token decimals 적용. */
    val amount: String,
    /** EVM chainId (문자열). */
    val chainId: String,
    /** ERC-20 컨트랙트 주소 — null 이면 native 전송. */
    val contractAddress: String? = null,
)

/** customer-backend `POST /sdk/transfer/build-hash` response. */
data class BuildTransferResponse(
    /** broadcast path 파라미터 (BTX-...). */
    val txId: String,
    /** MPC sign 의 id 슬롯에 그대로 넘김 — TRANSACTION 이면 TX-..., CONTRACT_CALL 이면 EXE-... */
    val signId: String,
    /** 서명 대상 keccak256 hash (0x-hex). */
    val messageHash: String,
    /** 서명 대상 message 종류 — TRANSACTION | CONTRACT_CALL. */
    val type: String,
)

/** customer-backend `POST /sdk/transfer/broadcast` request. */
data class BroadcastTransferRequest(
    val txId: String,
)

/**
 * customer-backend `POST /sdk/transfer/broadcast` response.
 *
 * [txHash] 는 EIP-7702 bundler 경로일 때 응답 시점에 아직 발급 안 됨 (null).
 * 이 때 [status] == "SIGNED" 이며 bundler 가 별도 시점에 onchain 전송 → 후속 polling 필요.
 * 일반 EOA 경로는 즉시 [txHash] 가 채워지고 [status] == "BROADCAST".
 */
data class BroadcastTransferResponse(
    val txHash: String? = null,
    val status: String = "",
    val batchTxId: String = "",
)
