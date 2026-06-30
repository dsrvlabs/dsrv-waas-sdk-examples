import {
  IsInt,
  IsNotEmpty,
  IsString,
  Matches,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * 결제 endpoint (출금/수령) 한쪽 — cross-chain TOPUP 에서 source 와 destination 이
 * 서로 다른 체인일 수 있으므로 chain / token / 주소를 endpoint 단위로 받는다.
 *
 * <p><b>token 이 체인별로 다른 이유</b>: 같은 USDC 라도 컨트랙트 주소는 체인마다 다르다
 * (예: base-sepolia USDC ≠ ethereum-sepolia USDC). 따라서 단일 token 으로는 cross-chain
 * 을 표현할 수 없어 endpoint 마다 tokenAddress 를 받는다.
 */
export class PaymentEndpointDto {
  /** EVM chain id (예: 84532 = base-sepolia, 11155111 = ethereum-sepolia). */
  @IsInt()
  @Min(1, { message: 'chainId must be positive' })
  chainId!: number;

  /** 해당 체인의 ERC-20 토큰 컨트랙트 주소. */
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'tokenAddress must be EVM 0x-prefixed 40 hex',
  })
  tokenAddress!: string;

  /** source = payer(NCW) 주소, destination = 수령자 주소. */
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'address must be EVM 0x-prefixed 40 hex',
  })
  address!: string;
}

/**
 * Topup 결제 요청 (RN 앱 → customer-backend).
 *
 * <p>{@code POST /payments} 단일 엔드포인트의 입력. customer-backend 가 내부에서
 * quote → paymentDigest 서명(고객사 PK) → execute 를 순차 처리하므로,
 * 클라이언트는 더 이상 서명/quote 결과를 첨부하지 않는다.
 *
 * <p><b>cross-chain</b>: source(출금) / destination(수령) 을 분리해 받는다.
 * same-chain 결제는 source 와 destination 의 chainId 를 동일하게 보내면 된다.
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

  /** 출금 — payer 가 결제하는 체인 + token + NCW 주소. paymentDigest 가 이 체인에 종속. */
  @ValidateNested()
  @Type(() => PaymentEndpointDto)
  source!: PaymentEndpointDto;

  /** 수령 — 수령 체인 + token + 수령자 주소 (보통 프로젝트 SETTLEMENT 지갑). */
  @ValidateNested()
  @Type(() => PaymentEndpointDto)
  destination!: PaymentEndpointDto;

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
