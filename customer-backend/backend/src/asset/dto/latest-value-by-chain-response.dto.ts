/**
 * Asset 가치 조회 응답 (customer-backend → 클라이언트).
 *
 * <p>price-hub {@code LatestValueByChainResponse} 를 그대로 전달한다. 클라이언트(앱)는
 * {@code holdings.totalValue} 로 보유분의 법정통화 가치를, {@code price.value} 로 단가를 표시한다.
 * 금액 필드(value / totalValue / amount)는 price-hub 가 BigDecimal 을 JSON number 로 직렬화한 값이다.
 */

/** price-hub AssetByChainInfo 와 1:1. */
export interface AssetByChainInfoDto {
  chainId: string;
  chainName: string;
  /** native 토큰이면 null. */
  contractAddress: string | null;
  symbol: string;
  name: string;
  /** ERC20 / NATIVE 등. */
  tokenStandard: string | null;
  /** native 토큰이면 null 일 수 있음. */
  decimals: number | null;
}

export interface LatestPriceDataDto {
  currency: string;
  value: number | string;
  /** 가격 기준 시각 (ISO 8601). */
  fetchedAt: string;
  /** 가격 출처 (REDIS / DB / API). */
  source: string;
}

export interface HoldingsDto {
  amount: number | string;
  totalValue: number | string;
}

export interface LatestValueByChainResponseDto {
  asset: AssetByChainInfoDto;
  price: LatestPriceDataDto;
  /** amount=0(또는 생략)이면 price-hub 가 생략 — 가격만 반환된다. */
  holdings?: HoldingsDto;
}
