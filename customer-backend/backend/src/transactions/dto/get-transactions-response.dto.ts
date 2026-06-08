/**
 * Transaction history 응답 (customer-backend → 클라이언트).
 *
 * <p>WaaS {@code PagedList<EwTransactionInfo>} 의 envelope 을 푼 결과를 그대로
 * 전달한다. 클라이언트(앱)는 items 를 리스트로 렌더링하고 pagination 으로 추가
 * 페이지 여부를 판단한다.
 */

/** WaaS EwTransactionInfo 와 1:1. */
export interface TransactionHistoryItemDto {
  /** WaaS 트랜잭션 비즈니스 키 (TX-...). */
  transactionId: string;
  chainId: string;
  /** 체인 계열 식별자 (EVM 등). */
  chainType: string;
  /** 트랜잭션 상태 그룹 (PENDING / COMPLETED / FAILED 등). */
  status: string;
  fromAddress: string;
  toAddress: string | null;
  /** onchain hash — 브로드캐스트 전이면 null. */
  txHash: string | null;
  /** 트랜잭션 종류 (transfer 등). */
  method: string | null;
  /** ISO 8601 생성 시각. */
  createdAt: string;
}

export interface TransactionHistoryPaginationDto {
  page: number;
  limit: number;
  total: number;
}

export interface GetTransactionsResponseDto {
  items: TransactionHistoryItemDto[];
  pagination: TransactionHistoryPaginationDto;
}
