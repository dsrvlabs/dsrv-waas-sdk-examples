package com.dsrv.wallet.example.wallet.model

import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * customer-backend `GET /sdk/transactions` 호출 client — transaction history 조회.
 *
 * customer-backend 가 자체 server-key (X_API_KEY) 로 WaaS 의
 * `GET /api/v1/embedded-wallets/ncw/transactions` (fromAddress 필터) 를 호출하므로
 * example 은 user token 을 보내지 않는다 ([TransferRepository] 와 동일 패턴).
 */
class TransactionHistoryRepository(private val backendUrl: String) {
    private val client = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    /**
     * @param address 조회 대상 지갑 주소 (fromAddress 필터)
     * @param page    1-base 페이지 번호
     * @param limit   페이지당 항목 수 (WaaS 최대 100)
     */
    suspend fun getTransactions(
        address: String,
        page: Int = 1,
        limit: Int = 20,
    ): TransactionHistoryResponse = withContext(Dispatchers.IO) {
        val url = "$backendUrl/sdk/transactions".toHttpUrl().newBuilder()
            .addQueryParameter("address", address)
            .addQueryParameter("page", page.toString())
            .addQueryParameter("limit", limit.toString())
            .build()
        val req = Request.Builder().url(url).get().build()
        client.newCall(req).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw RuntimeException("/sdk/transactions [${resp.code}]: $text")
            }
            gson.fromJson(text, TransactionHistoryResponse::class.java)
        }
    }
}

/** customer-backend `GET /sdk/transactions` response — WaaS EwTransactionInfo 와 1:1. */
data class TransactionHistoryItem(
    /** WaaS 트랜잭션 비즈니스 키 (TX-...). */
    val transactionId: String = "",
    val chainId: String = "",
    /** 체인 계열 식별자 (EVM 등). */
    val chainType: String = "",
    /** 트랜잭션 상태 그룹 (PENDING / COMPLETED / FAILED 등). */
    val status: String = "",
    val fromAddress: String = "",
    val toAddress: String? = null,
    /** onchain hash — 브로드캐스트 전이면 null. */
    val txHash: String? = null,
    /** 트랜잭션 종류 (transfer 등). */
    val method: String? = null,
    /** ISO 8601 생성 시각. */
    val createdAt: String = "",
)

data class TransactionHistoryPagination(
    val page: Int = 1,
    val limit: Int = 20,
    val total: Int = 0,
)

data class TransactionHistoryResponse(
    val items: List<TransactionHistoryItem> = emptyList(),
    val pagination: TransactionHistoryPagination = TransactionHistoryPagination(),
)
