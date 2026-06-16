package com.dsrv.wallet.example.wallet.model

import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * customer-backend `GET /sdk/asset/by-chain/latest-value` 호출 client — 자산 시세/보유 가치 조회.
 *
 * customer-backend 가 price-hub 시세를 프록시하므로 example 은 user token 을 보내지 않는다
 * ([TransactionHistoryRepository] 와 동일 패턴).
 */
class AssetValueRepository(private val backendUrl: String) {
    // Flutter/iOS(15s) 와 일관된 타임아웃 — 무응답 시 UI 무한 대기 방지.
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    /**
     * @param contractAddress ERC-20 토큰 주소. 네이티브 ETH 면 null/빈 문자열 → 쿼리에서 생략.
     * @param amount          사람이 읽는 십진 표기 (예: "0.5", raw wei 아님).
     * @param currency        시세 통화 (고정 KRW).
     */
    suspend fun getLatestValue(
        chainId: String,
        contractAddress: String?,
        amount: String,
        currency: String = "KRW",
    ): AssetLatestValueResponse = withContext(Dispatchers.IO) {
        val url = "$backendUrl/sdk/asset/by-chain/latest-value".toHttpUrl().newBuilder()
            .addQueryParameter("chainId", chainId)
            .addQueryParameter("currency", currency)
            .addQueryParameter("amount", amount)
            .apply {
                if (!contractAddress.isNullOrEmpty()) addQueryParameter("contractAddress", contractAddress)
            }
            .build()
        val req = Request.Builder().url(url).get().build()
        client.newCall(req).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw RuntimeException("/sdk/asset/by-chain/latest-value [${resp.code}]: $text")
            }
            gson.fromJson(text, AssetLatestValueResponse::class.java)
        }
    }
}

/** customer-backend `GET /sdk/asset/by-chain/latest-value` response — asset 메타데이터. */
data class AssetByChainInfo(
    val chainId: String = "",
    val chainName: String = "",
    val contractAddress: String? = null,
    val symbol: String = "",
    val name: String = "",
    val tokenStandard: String? = null,
    val decimals: Int = 0,
)

/** 단가 시세. value 는 JSON number 로 직렬화되지만 Gson 이 String 필드로 coerce 한다. */
data class LatestPriceData(
    val currency: String = "",
    val value: String = "",
    val fetchedAt: String = "",
    val source: String? = null,
)

/** 보유 가치 — 잔액 0 이면 response 에서 누락된다 (nullable). */
data class Holdings(
    val amount: String = "",
    val totalValue: String = "",
)

data class AssetLatestValueResponse(
    val asset: AssetByChainInfo = AssetByChainInfo(),
    val price: LatestPriceData = LatestPriceData(),
    val holdings: Holdings? = null,
)
