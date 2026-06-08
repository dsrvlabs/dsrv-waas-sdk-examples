import { IsInt, IsNotEmpty, IsString, Matches, Min } from 'class-validator';

/**
 * Topup 결제 요청 (RN 앱 → customer-backend).
 *
 * <p>{@code POST /payments} 단일 엔드포인트의 입력. customer-backend 가 내부에서
 * quote → paymentDigest 서명(고객사 PK) → execute 를 순차 처리하므로,
 * 클라이언트는 더 이상 서명/quote 결과를 첨부하지 않는다.
 */
export class PaymentRequestDto {
  /**
   * Payments(stablecoin) 가 식별하는 사용자 외부 참조키(external_user_ref).
   * SDK 가 결제 진입 시 주입(보통 RN 앱 로그인 사용자 ID).
   * stablecoin TOPUP 처리 시 walletTopup 매핑 키로 쓰임.
   */
  @IsString()
  @IsNotEmpty()
  sourceUserId!: string;

  @IsInt()
  @Min(1, { message: 'chainId must be positive' })
  chainId!: number;

  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'token must be EVM 0x-prefixed 40 hex',
  })
  token!: string;

  /** 사용자 NCW (smart account) 주소 — quote 의 payer 로 매핑. */
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'from must be EVM 0x-prefixed 40 hex',
  })
  from!: string;

  /** 수령자 — 보통 프로젝트 SETTLEMENT 지갑. */
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'to must be EVM 0x-prefixed 40 hex',
  })
  to!: string;

  /**
   * 결제 금액 — humanized BigDecimal 문자열 (예: "1.5" = 1.5 USDC, "0.0994" = 0.0994 USDC).
   *
   * <p><b>단위 boundary</b>: customer-backend 는 humanized 그대로 stablecoin 에 forward.
   * raw smallest-unit 변환 (× 10^decimals) 은 stablecoin 내부에서 token decimals 적용해 처리.
   * raw 정수 (예: "100000") 그대로 보내면 stablecoin 이 "100,000 USDC" 로 해석해 1,000,000 배
   * inflate 되어 ERC20 transfer revert.
   */
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]+(\.[0-9]+)?$/, {
    message: 'amount must be a positive decimal string (humanized, e.g. "1.5")',
  })
  amount!: string;

  /** 결제 타입 — 0 = 일반 결제. */
  @IsInt()
  @Min(0)
  paymentType!: number;
}
