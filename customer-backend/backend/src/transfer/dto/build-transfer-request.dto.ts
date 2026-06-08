import { IsNotEmpty, IsOptional, IsString, Matches } from 'class-validator';

/**
 * Transfer build 요청 (모바일 SDK example → customer-backend).
 *
 * <p>customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 WaaS 의
 * {@code POST /api/v1/transactions/ncw/transfer/build} 를 호출. 클라이언트는 user token 을 보내지 않는다.
 *
 * <p>WaaS NCW endpoint 는 batch shape ({@code items[] + atomic}) 을 받지만, SDK 의 단일
 * recipient transfer 와 같은 시그니처를 노출하므로 customer-backend 가 내부에서
 * {@code items[1] + atomic=false} 로 감싼다.
 */
export class BuildTransferRequestDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'fromAddress must be EVM 0x-prefixed 40 hex',
  })
  fromAddress!: string;

  @IsString()
  @IsNotEmpty()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'toAddress must be EVM 0x-prefixed 40 hex',
  })
  toAddress!: string;

  /** wei (base units, 정수 문자열). */
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9]+$/, { message: 'amount must be a positive integer string' })
  amount!: string;

  /** EVM chainId (문자열) — WaaS spec 이 string 으로 받음. */
  @IsString()
  @IsNotEmpty()
  chainId!: string;

  /** ERC-20 컨트랙트 주소 (있으면 ERC20 전송, 없으면 native). */
  @IsString()
  @IsOptional()
  @Matches(/^0x[a-fA-F0-9]{40}$/, {
    message: 'contractAddress must be EVM 0x-prefixed 40 hex when provided',
  })
  contractAddress?: string;
}
