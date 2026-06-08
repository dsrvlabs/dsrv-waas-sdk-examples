/**
 * Topup 결제 응답 (customer-backend → RN 앱).
 *
 * <p>Payments(stablecoin) 의 transaction 생성 응답을 relay.
 */
export interface PaymentResponseDto {
  transactionId: string;
  paymentUuid: string;
  status: string;
  txHash: string;
  submittedAt?: string;
}
