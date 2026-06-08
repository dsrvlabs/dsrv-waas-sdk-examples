import { IsNotEmpty, IsOptional, IsString, Matches } from 'class-validator';

/**
 * Transaction history 조회 요청 (모바일 SDK example → customer-backend).
 *
 * <p>customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 WaaS 의
 * {@code GET /api/v1/embedded-wallets/ncw/transactions} 를
 * {@code searchBy=FROM_ADDRESS&keyword={address}} 로 호출. 클라이언트는 user token 을
 * 보내지 않는다 (transfer 흐름과 동일 패턴).
 *
 * <p>address 기준인 이유: WaaS 의 사용자/계정별 조회는 path 에 auth 내부 EndUser UUID
 * 가 필요한데 SDK/앱은 그 값을 모른다. 앱이 이미 아는 지갑 address 로 필터하는 게
 * transfer build (fromAddress 만 전달) 와 같은 정보 단위라 example 에 적합.
 *
 * <p>전역 ValidationPipe 가 {@code transform} 없이 동작하므로 query 값은 모두
 * string 으로 받고, page/limit 은 숫자 형식만 검증 후 WaaS 에 그대로 전달한다.
 */
export class GetTransactionsRequestDto {
  /** 조회 대상 지갑 주소 (fromAddress 필터). */
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'address must be EVM 0x-prefixed 40 hex',
  })
  address!: string;

  /** 페이지 번호 (1-base). 기본 1. */
  @IsString()
  @IsOptional()
  @Matches(/^[0-9]+$/, { message: 'page must be a positive integer string' })
  page?: string;

  /** 페이지당 항목 수. 기본 20, 최대 100 (WaaS 검증). */
  @IsString()
  @IsOptional()
  @Matches(/^[0-9]+$/, { message: 'limit must be a positive integer string' })
  limit?: string;
}
