package com.dsrv.wallet.example.wallet.model

/**
 * customer-backend `POST /payments` 의 한쪽 endpoint (출금=source / 수령=destination).
 *
 * cross-chain (DNT-5965): source 와 destination 이 서로 다른 체인일 수 있어 chain/token/주소를
 * endpoint 단위로 받는다. 같은 USDC 라도 컨트랙트 주소는 체인마다 달라 [tokenAddress] 도 endpoint 별.
 */
data class PaymentEndpoint(
    val chainId: Int,
    val tokenAddress: String,
    /** source = payer(NCW) 주소, destination = 수령자 주소. */
    val address: String,
)

/**
 * customer-backend `POST /payments` 요청.
 *
 * customer-backend 가 내부에서 stablecoin Payments quote → paymentDigest 서명 → execute 를
 * 한 번에 처리. 클라이언트는 paymentDigest 서명을 직접 하지 않음.
 *
 * cross-chain (DNT-5965): 출금([source]) / 수령([destination]) 을 분리해 보낸다.
 * same-chain 결제는 두 endpoint 의 chainId/tokenAddress 를 동일하게 보내면 된다.
 */
data class PaymentRequest(
    val sourceUserId: String,
    val source: PaymentEndpoint,
    val destination: PaymentEndpoint,
    val amount: String,
    val paymentType: Int,
)

/** customer-backend `POST /payments` 응답 — stablecoin Payments transaction 결과 relay. */
data class PaymentResponse(
    val transactionId: String,
    val paymentUuid: String,
    val status: String,
    val txHash: String? = null,
    val submittedAt: String? = null,
)
