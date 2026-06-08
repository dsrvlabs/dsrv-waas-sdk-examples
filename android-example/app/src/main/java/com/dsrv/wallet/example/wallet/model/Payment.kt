package com.dsrv.wallet.example.wallet.model

/**
 * customer-backend `POST /payments` 요청.
 *
 * customer-backend 가 내부에서 stablecoin Payments quote → paymentDigest 서명 → execute 를
 * 한 번에 처리. 클라이언트는 paymentDigest 서명을 직접 하지 않음.
 */
data class PaymentRequest(
    val sourceUserId: String,
    val chainId: Int,
    val token: String,
    val from: String,
    val to: String,
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
