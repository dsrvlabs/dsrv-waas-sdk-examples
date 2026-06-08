/**
 * Payments(stablecoin) quote 응답 — customer-backend 내부 전용 타입.
 *
 * <p>{@code POST /api/transactions/quote} 의 응답. customer-backend 는
 * `paymentDigest` 를 고객사 PK 로 서명하고, `params` 를 execute body 에 옮겨 담는다.
 * (클라이언트로 직접 relay 하지 않는다.)
 */
/**
 * Fee allocation entry — stablecoin quote 응답에서 raw smallest-unit (예: uUSDC) BigInteger 문자열.
 *
 * <p><b>단위 boundary 예외</b>: 다른 amount 는 humanized BigDecimal 이지만, 본 필드는 컨트랙트
 * keccak(feeAllocations) == feeAllocationsHash 검증 대상이라 변환 금지. quote 응답에서 받은
 * 값을 execute 시 그대로 echo.
 */
export interface FeeAllocationDto {
  receiver: string;
  /** raw smallest-unit BigInteger string (예: "60" = 0.00006 USDC). 변환 금지. */
  amount: string;
}

/**
 * Payments(stablecoin) quote 응답의 params — execute body 로 그대로 옮겨담는 *서명 대상 필드들만* 포함.
 *
 * <p>다른 필드(projectId/token/payer/to/amount/paymentType)는 PaymentRequestDto 에서 이미 알고 있으므로
 * quote 응답에 중복으로 받지 않는다.
 * <p>maxFeeAmount 는 PaymentContract spec 에서 삭제됨 — feeAllocations 만으로 fee 처리.
 */
export interface QuoteParamsDto {
  /** Payments 가 발급한 paymentUuid — 0x-hex. */
  paymentUuid: string;
  customerEpoch: number;
  /** Unix seconds (UTC) — quote 발급 시점 +5분 등. */
  deadline: number;
  /** keccak256(feeAllocations) — 0x-hex 32 bytes. */
  feeAllocationsHash: string;
  /** fee 분배 내역 — 응답에 포함될 경우 execute 로 그대로 전달. */
  feeAllocations: FeeAllocationDto[];
}

export interface QuoteResponseDto {
  /** EIP-712 paymentDigest — 32 bytes 0x-hex. 서명 대상. */
  paymentDigest: string;
  params: QuoteParamsDto;
}
