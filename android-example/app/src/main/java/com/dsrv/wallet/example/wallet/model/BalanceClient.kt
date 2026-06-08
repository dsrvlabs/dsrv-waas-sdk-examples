package com.dsrv.wallet.example.wallet.model

import com.dsrv.wallet.example.wallet.config.TokenConfig
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.math.BigInteger
import java.util.concurrent.TimeUnit

/**
 * 읽기 전용 JSON-RPC 클라이언트 — 잔액 조회용.
 * RPC URL 은 [TokenConfig.getRpcUrl] 매핑.
 */
class BalanceClient {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    /** 네이티브 코인 (ETH 등) 잔액 — wei. */
    suspend fun getNativeBalance(chainId: String, address: String): BigInteger = withContext(Dispatchers.IO) {
        val url = TokenConfig.getRpcUrl(chainId)
            ?: throw IllegalArgumentException("chainId=$chainId 의 RPC URL 이 정의되지 않았습니다")
        val payload = """{"jsonrpc":"2.0","method":"eth_getBalance","params":["$address","latest"],"id":1}"""
        callRpc(url, payload)
    }

    /** ERC-20 잔액 — base units. balanceOf(address) 호출 (selector 0x70a08231). */
    suspend fun getErc20Balance(
        chainId: String,
        tokenAddress: String,
        ownerAddress: String,
    ): BigInteger = withContext(Dispatchers.IO) {
        val url = TokenConfig.getRpcUrl(chainId)
            ?: throw IllegalArgumentException("chainId=$chainId 의 RPC URL 이 정의되지 않았습니다")
        val ownerNo0x = ownerAddress.removePrefix("0x").lowercase().padStart(64, '0')
        val data = "0x70a08231$ownerNo0x"
        val payload = """{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"$tokenAddress","data":"$data"},"latest"],"id":1}"""
        callRpc(url, payload)
    }

    private fun callRpc(url: String, payload: String): BigInteger {
        val body = payload.toRequestBody("application/json".toMediaType())
        val req = Request.Builder().url(url).post(body).build()
        client.newCall(req).execute().use { resp ->
            val bodyStr = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw RuntimeException("HTTP ${resp.code}: $bodyStr")
            val root = gson.fromJson(bodyStr, JsonObject::class.java)
            root.getAsJsonObject("error")?.let {
                throw RuntimeException("RPC error: ${it.get("message")?.asString ?: bodyStr}")
            }
            val hex = root.get("result")?.asString
                ?: throw RuntimeException("missing result: $bodyStr")
            return parseHexToBigInteger(hex)
        }
    }

    private fun parseHexToBigInteger(hex: String): BigInteger {
        val clean = hex.removePrefix("0x").ifEmpty { "0" }
        return BigInteger(clean, 16)
    }
}
