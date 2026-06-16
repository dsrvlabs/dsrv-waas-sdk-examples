import { IsNotEmpty, IsOptional, IsString, Matches } from 'class-validator';

/**
 * Asset 가치 조회 요청 (모바일 SDK example → customer-backend → price-hub).
 *
 * <p>전역 ValidationPipe 가 {@code transform} 없이 동작하므로 query 값은 모두 string 으로 받고,
 * price-hub 에 그대로 전달한다. currency/amount 는 형식만 1차 검증(빠른 피드백)하고, 최종
 * 정규화·검증(미등록 코인 404, 가격 미가용 503 등)은 price-hub 가 수행한다.
 */
export class GetLatestValueByChainRequestDto {
  /**
   * 체인 ID. EVM 은 EIP-155 정수 문자열("1", "11155111"), 비-EVM 은 canonical 식별자
   * ("mainnet-beta" 등). 체인 계열마다 형식이 달라 형식 정규식은 두지 않는다.
   */
  @IsString()
  @IsNotEmpty()
  chainId!: string;

  /**
   * 토큰 컨트랙트 주소. 생략/빈값이면 price-hub 가 해당 체인 native 가스 토큰으로 처리.
   * 비-EVM 컨트랙트 주소도 허용해야 하므로 EVM 정규식은 두지 않는다(price-hub 가 검증).
   */
  @IsString()
  @IsOptional()
  contractAddress?: string;

  /** 통화 (KRW / USD, case-insensitive). 생략 시 price-hub 기본값(KRW) 적용. */
  @IsString()
  @IsOptional()
  @Matches(/^(KRW|USD)$/i, { message: 'currency must be KRW or USD' })
  currency?: string;

  /**
   * 보유 수량 (humanized 토큰 수량, raw smallest-unit 아님). 생략 시 price-hub 가 0 으로 처리해
   * 가격만 반환한다. 음수는 거부.
   */
  @IsString()
  @IsOptional()
  @Matches(/^[0-9]+(\.[0-9]+)?$/, {
    message: 'amount must be a non-negative decimal string',
  })
  amount?: string;
}
