package com.dsrv.wallet.example.wallet.model

import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * customer-backend `GET /sdk/asset/accounts/{accountId}` 호출 client —
 * WaaS 계정 자산 목록(계정의 모든 주소 잔고를 chain·asset 단위로 합산)을 조회한다. 기존 RPC 직접 호출(BalanceClient)을 대체.
 *
 * customer-backend 가 자체 server-key (X_API_KEY) 로 WaaS 의
 * `GET /api/v1/embedded-wallets/ncw/accounts/{accountId}/assets` 를
 * 호출하므로 example 은 user token 을 보내지 않는다 ([TransactionHistoryRepository]/
 * [AssetValueRepository] 와 동일 패턴). userId·addressId 불필요 — projectId(passport) + accountId 로 스코핑.
 */
class AccountAssetRepository(private val backendUrl: String) {
    // Flutter/iOS(15s) 와 일관된 타임아웃 — 무응답 시 UI 무한 대기 방지.
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    suspend fun getAccountAssets(
        accountId: String,
    ): AccountAssetsResponse = withContext(Dispatchers.IO) {
        val url = "$backendUrl/sdk/asset/accounts/$accountId".toHttpUrl()
        val req = Request.Builder().url(url).get().build()
        client.newCall(req).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) {
                throw RuntimeException("/sdk/asset/accounts/$accountId [${resp.code}]: $text")
            }
            gson.fromJson(text, AccountAssetsResponse::class.java)
        }
    }
}

/** `GET /sdk/asset/accounts/{accountId}` response item — WaaS AccountAssetInfo 와 1:1. */
data class AccountAssetItem(
    val chainId: String = "",
    /** 체인 계열 (EVM / SVM). */
    val chainType: String = "",
    /** 토큰 컨트랙트 주소. native 코인은 null. */
    val contractAddress: String? = null,
    /** raw smallest-unit 잔고 (wei 등, decimals 미적용). 정밀도 보존 위해 String. */
    val balance: String = "",
    /** WaaS 가 제공할 때만 존재하는 자산 심볼(예: "ETH","USDC"). 없으면 앱이 price-hub 로 보완. */
    val symbol: String? = null,
)

data class AccountAssetsPagination(
    val page: Int = 1,
    val limit: Int = 0,
    val total: Int = 0,
)

data class AccountAssetsResponse(
    val items: List<AccountAssetItem> = emptyList(),
    val pagination: AccountAssetsPagination = AccountAssetsPagination(),
)

/**
 * 드롭다운 한 줄에 필요한 자산 표시 정보 — WaaS 자산(raw balance) + price-hub 메타(symbol/decimals)
 * 를 합쳐 만든다. symbol/name/decimals 는 price-hub `by-chain/latest-value` 응답에서 온다
 * (WaaS 자산 API 는 이 메타를 주지 않음).
 */
data class AssetRow(
    val chainId: String,
    /** native 코인은 null. */
    val contractAddress: String?,
    /** raw smallest-unit 잔고 (decimals 미적용). 정밀도 보존 위해 String. */
    val rawBalance: String,
    val symbol: String,
    val name: String,
    val decimals: Int,
    /** decimals 적용된 사람이 읽는 잔고 ("1.5"). */
    val humanizedBalance: String,
) {
    /** (chainId, contractAddress) 조합이 자산 고유키. native 는 "native". */
    val id: String get() = "$chainId:${contractAddress?.lowercase() ?: "native"}"
    val isNative: Boolean get() = contractAddress.isNullOrEmpty()
    /** 드롭다운 라벨: 심볼만("ETH"). 잔액은 별도 잔액 row 에 표시. */
    val displayLabel: String get() = symbol
}
