import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';

import { GetLatestValueByChainRequestDto } from './dto/get-latest-value-by-chain-request.dto';
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

  /** price-hub 최신 가치 조회 — chainId + contractAddress(생략 시 native) 기준. */
  async getLatestValueByChain(
    request: GetLatestValueByChainRequestDto,
  ): Promise<LatestValueByChainResponseDto> {
    const params: Record<string, string> = { chainId: request.chainId };
    // 생략된 선택 param 은 싣지 않는다 — price-hub 가 자체 기본값(native, KRW, amount=0)을 적용.
    if (request.contractAddress)
      params.contractAddress = request.contractAddress;
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
        `asset.latest-value:ok chainId=${request.chainId} contract=${request.contractAddress ?? 'NATIVE'} currency=${price.currency} value=${price.value}`,
      );
      return { asset, price, holdings };
    } catch (error) {
      this.throwUpstreamError(error, 'price-hub latest-value query failed');
    }
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
