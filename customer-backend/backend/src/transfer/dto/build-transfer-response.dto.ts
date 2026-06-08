/**
 * Transfer build 응답 (customer-backend → 클라이언트).
 *
 * <p>WaaS {@code items[0]} 을 풀어 단건 형태로 변환한 결과. SDK 의 sign() 호출에 필요한
 * {@code txId / signId / messageHash / type} 을 클라이언트가 그대로 사용한다.
 */
export interface BuildTransferResponseDto {
  /** broadcast 시 path 파라미터로 쓰이는 batch tx id (BTX-...). */
  txId: string;
  /**
   * MPC sign 의 id 슬롯에 들어갈 값.
   * type=TRANSACTION    → transactionId (TX-...)
   * type=CONTRACT_CALL  → addressSmartAccountId (EXE-...)
   */
  signId: string;
  /** 서명 대상 keccak256 hash (0x-hex). */
  messageHash: string;
  /** message 종류 식별자 — TRANSACTION | CONTRACT_CALL. */
  type: string;
}
