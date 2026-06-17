import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';

import { GetLatestValueByChainRequestDto } from './dto/get-latest-value-by-chain-request.dto';
import {
  AccountAssetItemDto,
  AccountAssetsPaginationDto,
  GetAccountAssetsResponseDto,
} from './dto/get-account-assets-response.dto';
import {
  AssetByChainInfoDto,
  HoldingsDto,
  LatestPriceDataDto,
  LatestValueByChainResponseDto,
} from './dto/latest-value-by-chain-response.dto';

/**
 * Asset 가치 조회 proxy — price-hub 와의 통신을 customer-backend 가 대신 수행.
 *
 * <p>인증: customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 DSRV Gateway 호출.
 * Gateway 가 {@code x-api-key → X-User-Passport JWT} 변환 후 price-hub 에 전달
 * (WaaS / Payments 프록시와 동일 패턴 — base URL 공유, path prefix 만 다름).
 *
 * <p>price-hub endpoint:
 * {@code GET /price-hub/api/v1/asset/by-chain/latest-value} — Gateway 가 {@code /price-hub} prefix 를
 * 떼고 price-hub 의 {@code /api/v1/asset/by-chain/latest-value} 로 라우팅한다. 응답은
 * {@code { asset, price, holdings }} 이며 holdings 는 amount=0 일 때 생략된다.
 *
 * <p><b>단위 boundary</b>: amount 는 humanized 토큰 수량 문자열 (예: "0.5" = 0.5 ETH).
 * raw smallest-unit(wei 등) 이 아니라 사람이 읽는 수량이어야 하며, customer-backend 는
 * 변환 없이 그대로 forward 한다. price-hub 가 amount × 단가로 totalValue 를 계산한다.
 */
@Injectable()
export class AssetService {
  /** WaaS BasePageRequest 의 limit 상한 (@Max(100)). 한 페이지로 최대 100개. */
  private static readonly WAAS_MAX_LIMIT = 100;
  /** total 이상이라도 무한루프 방지용 페이지 상한 (100 * 50 = 5000개). */
  private static readonly MAX_PAGES = 50;

  private readonly logger = new Logger(AssetService.name);
  private readonly dsrvApiBaseUrl: string;
  private readonly apiKey: string;

  constructor(configService: ConfigService) {
    this.dsrvApiBaseUrl = configService.getOrThrow<string>('DSRV_API_BASE_URL');
    this.apiKey = configService.getOrThrow<string>('X_API_KEY');
  }

  private get axiosHeaders() {
    return {
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
      },
    };
  }

  /** native 코인을 가리키는 price-hub contractAddress sentinel. */
  private static readonly NATIVE_CONTRACT = 'NATIVE';

  /** price-hub 최신 가치 조회 — chainId + contractAddress(생략 시 'NATIVE') 기준. */
  async getLatestValueByChain(
    request: GetLatestValueByChainRequestDto,
  ): Promise<LatestValueByChainResponseDto> {
    const params: Record<string, string> = { chainId: request.chainId };
    // native 코인(contractAddress 생략/빈값)은 'NATIVE' sentinel 로 명시한다.
    // price-hub 는 contractAddress 를 생략하면 native 단가·메타를 반환하지 않으므로,
    // native 값을 받으려면 contractAddress=NATIVE 를 반드시 실어야 한다.
    params.contractAddress =
      request.contractAddress?.trim() || AssetService.NATIVE_CONTRACT;
    if (request.currency) params.currency = request.currency;
    if (request.amount) params.amount = request.amount;

    const url = `${this.dsrvApiBaseUrl}/price-hub/api/v1/asset/by-chain/latest-value`;

    try {
      const response = await axios.get(url, {
        ...this.axiosHeaders,
        params,
        // price-hub 무응답 시 요청이 매달려 워커가 고갈되지 않도록 명시적 timeout.
        timeout: 15_000,
      });

      // price-hub 는 envelope 없이 { asset, price, holdings } 를 직접 반환.
      // Gateway 가 { data } 로 감쌀 가능성에 대비해 fallback.
      const payload = (response.data?.data ?? response.data) as Record<
        string,
        unknown
      >;
      const asset = payload?.asset as AssetByChainInfoDto | undefined;
      const price = payload?.price as LatestPriceDataDto | undefined;
      if (!asset || !price) {
        this.logger.error(
          `asset.latest-value:invalid-schema body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'price-hub latest-value response missing asset/price',
          HttpStatus.BAD_GATEWAY,
        );
      }

      // holdings 는 amount=0 이면 price-hub 가 생략 — undefined 그대로 두면 응답 JSON 에서 빠진다.
      const holdings = payload?.holdings as HoldingsDto | undefined;

      this.logger.log(
        `asset.latest-value:ok chainId=${request.chainId} contract=${params.contractAddress} currency=${price.currency} value=${price.value}`,
      );
      return { asset, price, holdings };
    } catch (error) {
      this.throwUpstreamError(error, 'price-hub latest-value query failed');
    }
  }

  /**
   * WaaS NCW 계정 자산 목록 조회 — accountId 로 스코핑 (userId·addressId 불필요).
   *
   * <p>WaaS endpoint:
   * {@code GET /api/v1/embedded-wallets/ncw/accounts/{accountId}/assets?page=&limit=100}
   * — projectId(passport) + accountId 로 스코핑(IDOR 방지). 계정에 속한 모든 주소의 잔고를
   * (chain, asset) 단위로 합산한다. 응답은 {@code PagedList<AccountAssetInfo>} ({@code items[] + pagination}).
   *
   * <p>{@code /users/{userId}/...} endpoint 를 쓰지 않는 이유: path 의 userId 는 auth 내부
   * EndUser UUID 라서 SDK/앱이 알 수 없는 값 (transactions 프록시와 동일 이유). 앱이 이미
   * 가진 accountId 로 조회한다.
   *
   * <p><b>전체 목록 보장</b>: limit=100 으로 받고 {@code pagination.total > 100} 이면 다음
   * 페이지를 이어 받아 모두 합쳐 반환한다 (앱은 페이지네이션 없이 전체 자산을 드롭다운에 노출).
   */
  async getAccountAssetList(
    accountId: string,
  ): Promise<GetAccountAssetsResponseDto> {
    const url =
      `${this.dsrvApiBaseUrl}/waas/api/v1/embedded-wallets/ncw/accounts/` +
      `${encodeURIComponent(accountId)}/assets`;

    const all: AccountAssetItemDto[] = [];
    let page = 1;
    let total = 0;

    try {
      do {
        const pageResult = await this.fetchAssetPage(url, page);
        all.push(...pageResult.items);
        total = pageResult.pagination.total;
        page += 1;
      } while (all.length < total && page <= AssetService.MAX_PAGES);

      if (all.length < total) {
        this.logger.warn(
          `asset.account-list:truncated collected=${all.length} total=${total} accountId=${accountId}`,
        );
      }
      this.logger.log(
        `asset.account-list:ok accountId=${accountId} count=${all.length} total=${total}`,
      );
      return { items: all, pagination: { page: 1, limit: all.length, total } };
    } catch (error) {
      this.throwUpstreamError(error, 'WaaS account assets query failed');
    }
  }

  /** 단일 페이지 조회 — balance 정밀도 보존을 위해 text 로 받아 안전 파싱. */
  private async fetchAssetPage(
    url: string,
    page: number,
  ): Promise<{
    items: AccountAssetItemDto[];
    pagination: AccountAssetsPaginationDto;
  }> {
    const response = await axios.get<string>(url, {
      headers: this.axiosHeaders.headers,
      params: {
        page: String(page),
        limit: String(AssetService.WAAS_MAX_LIMIT),
      },
      // balance(raw BigInteger)의 JS number 정밀도 손실 방지: text 로 받아 직접 파싱한다.
      responseType: 'text',
      transformResponse: (data) => data,
      timeout: 15_000,
    });

    const parsed = this.parseBalanceSafeJson(response.data);
    // WaaS envelope: { requestId, data: { items, pagination } } — fallback to direct payload.
    const payload = (parsed?.data ?? parsed) as Record<string, unknown>;
    const rawItems = payload?.items as
      | Array<Record<string, unknown>>
      | undefined;
    const pagination = payload?.pagination as
      | AccountAssetsPaginationDto
      | undefined;
    if (!Array.isArray(rawItems) || !pagination) {
      const preview =
        typeof response.data === 'string'
          ? response.data.slice(0, 500)
          : JSON.stringify(response.data);
      this.logger.error(`asset.account-list:invalid-schema body=${preview}`);
      throw new HttpException(
        'WaaS account assets response missing items/pagination',
        HttpStatus.BAD_GATEWAY,
      );
    }

    const items: AccountAssetItemDto[] = rawItems.map((it) => {
      // symbol 은 WaaS 가 제공할 때만 통과(옵션) — 없으면 앱이 price-hub 로 보완. decimals 는 통과 안 함.
      const symbol = it.symbol;
      return {
        chainId: String(it.chainId),
        chainType: String(it.chainType),
        // native 코인은 WaaS 가 contractAddress 를 생략(@JsonInclude NON_DEFAULT) → null 정규화.
        contractAddress:
          (it.contractAddress as string | null | undefined) ?? null,
        balance: it.balance == null ? '0' : String(it.balance),
        ...(typeof symbol === 'string' && symbol.length > 0 ? { symbol } : {}),
      };
    });
    return { items, pagination };
  }

  /**
   * balance(raw BigInteger)의 JS number 정밀도 손실 방지 — {@code JSON.parse} 전에 "balance"
   * number literal 을 string 으로 감싼다. page/limit/total 은 작은 count 라 number 로 둔다.
   */
  private parseBalanceSafeJson(text: string): Record<string, unknown> {
    const safe = text.replace(/("balance"\s*:\s*)(-?\d+)/g, '$1"$2"');
    return JSON.parse(safe) as Record<string, unknown>;
  }

  private throwUpstreamError(error: unknown, defaultMsg: string): never {
    if (error instanceof HttpException) throw error;
    if (axios.isAxiosError(error)) {
      const ax = error as AxiosError;
      this.logger.error(
        `asset.upstream:error status=${ax.response?.status} body=${JSON.stringify(ax.response?.data)}`,
      );
      throw new HttpException(
        (ax.response?.data as object) ?? defaultMsg,
        ax.response?.status ?? HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
    this.logger.error(`asset.unknown:error ${String(error)}`);
    throw new HttpException(defaultMsg, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
