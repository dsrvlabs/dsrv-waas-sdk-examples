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
   * MPC sign 의 id 슬롯에 들어갈 값. WaaS 의 Gas Sponsoring 분기에 따라 의미가 다름:
   *   type=GS_OFF → transactionId (TX-...) — 자기 가스 부담
   *   type=GS_ON  → batchTxId (BTX-...) — gas sponsor 활성 (Smart Account 경유)
   */
  signId: string;
  /** 서명 대상 keccak256 hash (0x-hex). */
  messageHash: string;
  /** message 종류 식별자 — `GS_ON` | `GS_OFF` (Gas Sponsoring on/off). */
  type: string;
}
