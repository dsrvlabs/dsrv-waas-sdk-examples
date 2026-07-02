/**
 * Topup 결제 응답 (customer-backend → RN 앱).
 *
 * <p>Payments(stablecoin) 의 transaction 생성 응답을 relay.
 */
export interface PaymentResponseDto {
  transactionId: string;
  paymentUuid: string;
  status: string;
  /** bundler/async 경로에서는 접수 시점에 null — status 로 진행상태를 판단하고 후속 조회로 확정한다. */
  txHash: string | null;
  submittedAt?: string;
}
