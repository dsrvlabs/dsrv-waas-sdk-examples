/**
 * 계정 자산 목록 응답 (customer-backend → 클라이언트).
 *
 * <p>WaaS {@code GET /api/v1/embedded-wallets/ncw/accounts/{accountId}/assets}
 * ({@code PagedList<AccountAssetInfo>}) 를 그대로 전달한다. projectId(passport) + accountId 로
 * 스코핑(userId·addressId 불필요), 계정에 속한 모든 주소의 잔고를 (chain, asset) 단위로 합산.
 *
 * <p><b>balance precision</b>: WaaS 는 balance(raw BigInteger)를 따옴표 없는 JSON number 로
 * 직렬화한다. JS {@code JSON.parse} 는 2^53 초과 정수에서 정밀도를 잃으므로 customer-backend 가
 * 응답을 text 로 받아 balance 를 string 으로 보존해 forward 한다.
 *
 * <p><b>native 정규화</b>: native 코인은 contractAddress 를 항상 null 로 정규화한다.
 *
 * <p><b>symbol (옵션)</b>: WaaS 응답이 asset 심볼을 포함하면 그대로 통과시킨다. 없으면 앱이
 * price-hub 로 보완한다(표준 티커 "ETH","USDC"). decimals 는 WaaS 가 보유하지 않으므로 항상
 * price-hub 에서 받는다(여기로 통과시키지 않음).
 */

/** WaaS AccountAssetInfo 와 1:1 (정밀도 보존 위해 balance 는 string). */
export interface AccountAssetItemDto {
  /** EVM chain id 정수 문자열 ("1", "11155111"). */
  chainId: string;
  /** 체인 계열 (EVM / SVM). */
  chainType: string;
  /** 토큰 컨트랙트 주소. native 코인은 null. */
  contractAddress: string | null;
  /** raw smallest-unit 잔고 (wei 등, decimals 미적용). 정밀도 보존 위해 string. */
  balance: string;
  /** WaaS 제공 시 자산 심볼(예: "ETH","USDC"). 없으면 앱이 price-hub 로 보완. decimals 는 price-hub 전용. */
  symbol?: string;
}

export interface AccountAssetsPaginationDto {
  page: number;
  limit: number;
  total: number;
}

export interface GetAccountAssetsResponseDto {
  items: AccountAssetItemDto[];
  pagination: AccountAssetsPaginationDto;
}
