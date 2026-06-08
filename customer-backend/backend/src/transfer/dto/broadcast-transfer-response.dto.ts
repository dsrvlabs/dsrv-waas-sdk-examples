/**
 * Transfer broadcast 응답.
 *
 * <p>{@code txHash} 는 EIP-7702 bundler 경로일 때 응답 시점에 아직 발급 안 됨 (null).
 * 이 때 {@code status === 'SIGNED'} 이며 bundler 가 별도 시점에 onchain 전송 → 후속 polling 필요.
 * 일반 EOA 경로는 즉시 {@code txHash} 가 채워지고 {@code status === 'BROADCAST'}.
 */
export interface BroadcastTransferResponseDto {
  /** 체인상 transaction hash — bundler 경로에서는 null. */
  txHash: string | null;
  /** WaaS TransactionStatus — SIGNED (bundler 대기) / BROADCAST (전송됨) / ... */
  status: string;
  /** WaaS batchTxId — 후속 polling 의 키. */
  batchTxId: string;
}
