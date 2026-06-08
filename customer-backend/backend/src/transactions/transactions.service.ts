import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';

import { GetTransactionsRequestDto } from './dto/get-transactions-request.dto';
import {
  GetTransactionsResponseDto,
  TransactionHistoryItemDto,
  TransactionHistoryPaginationDto,
} from './dto/get-transactions-response.dto';

/**
 * Transaction history proxy — WaaS 와의 통신을 customer-backend 가 대신 수행.
 *
 * <p>인증: customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 DSRV Gateway 호출.
 * Gateway 가 {@code x-api-key → X-User-Passport JWT} 변환 후 WaaS 에 전달. 클라이언트는
 * 사용자 토큰을 보내지 않는다 (transfer build/broadcast 흐름과 동일 패턴).
 *
 * <p>WaaS endpoint:
 * {@code GET /api/v1/embedded-wallets/ncw/transactions?searchBy=FROM_ADDRESS&keyword={address}}
 * — 프로젝트 범위 임베디드 지갑(NCW) 트랜잭션 목록을 지갑 address 로 필터. 응답은
 * {@code PagedList<EwTransactionInfo>} ({@code items[] + pagination}).
 *
 * <p>사용자/계정별 endpoint ({@code /users/{userId}/...}) 를 쓰지 않는 이유: path 의
 * userId 는 auth 내부 EndUser UUID 라서 SDK/앱이 알 수 없는 값. address 필터는
 * 대소문자 무관 contains (WaaS TransactionRepositoryCustomImpl 참조).
 */
@Injectable()
export class TransactionsService {
  private readonly logger = new Logger(TransactionsService.name);
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

  /** WaaS NCW 트랜잭션 목록 조회 — 지갑 address(fromAddress) 필터. */
  async getTransactions(
    request: GetTransactionsRequestDto,
  ): Promise<GetTransactionsResponseDto> {
    const params: Record<string, string> = {
      searchBy: 'FROM_ADDRESS',
      keyword: request.address,
    };
    if (request.page) params.page = request.page;
    if (request.limit) params.limit = request.limit;

    const url = `${this.dsrvApiBaseUrl}/waas/api/v1/embedded-wallets/ncw/transactions`;

    try {
      const response = await axios.get(url, {
        ...this.axiosHeaders,
        params,
      });

      // WaaS envelope: { requestId, data: { items: [...], pagination: {...} } }.
      // Some legacy endpoints may return the payload directly — fallback to response.data.
      const payload = (response.data?.data ?? response.data) as Record<
        string,
        unknown
      >;
      const items = payload?.items as TransactionHistoryItemDto[] | undefined;
      const pagination = payload?.pagination as
        | TransactionHistoryPaginationDto
        | undefined;
      if (!Array.isArray(items) || !pagination) {
        this.logger.error(
          `transactions.get:invalid-schema body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'WaaS transactions response missing items/pagination',
          HttpStatus.BAD_GATEWAY,
        );
      }

      this.logger.log(
        `transactions.get:ok address=${request.address} count=${items.length} total=${pagination.total}`,
      );
      return { items, pagination };
    } catch (error) {
      this.throwUpstreamError(error, 'WaaS transactions query failed');
    }
  }

  private throwUpstreamError(error: unknown, defaultMsg: string): never {
    if (error instanceof HttpException) throw error;
    if (axios.isAxiosError(error)) {
      const ax = error as AxiosError;
      this.logger.error(
        `transactions.upstream:error status=${ax.response?.status} body=${JSON.stringify(ax.response?.data)}`,
      );
      throw new HttpException(
        (ax.response?.data as object) ?? defaultMsg,
        ax.response?.status ?? HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
    this.logger.error(`transactions.unknown:error ${String(error)}`);
    throw new HttpException(defaultMsg, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
