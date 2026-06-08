import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';

import { BuildTransferRequestDto } from './dto/build-transfer-request.dto';
import { BuildTransferResponseDto } from './dto/build-transfer-response.dto';
import { BroadcastTransferRequestDto } from './dto/broadcast-transfer-request.dto';
import { BroadcastTransferResponseDto } from './dto/broadcast-transfer-response.dto';

/**
 * Transfer build / broadcast proxy — WaaS 와의 통신을 customer-backend 가 대신 수행.
 *
 * <p>인증: customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 DSRV Gateway 호출.
 * Gateway 가 {@code x-api-key → X-User-Passport JWT} 변환 후 WaaS 에 전달. 클라이언트는
 * 사용자 토큰을 보내지 않는다 (auth/registration 흐름과 동일 패턴).
 *
 * <p>build 단계는 단일 recipient 를 받아 WaaS 의 batch shape ({@code items[] + atomic})
 * 으로 감싸서 호출하고, 응답의 {@code items[0]} 을 풀어 단건 응답으로 변환한다.
 *
 * <p>sign 단계는 customer-backend 가 처리하지 않는다 — MPC keyShare 가 사용자 디바이스에
 * 있어서 디바이스 ↔ MPC 서버 직통이며 SDK 의 {@code DSRVWallet.sign()} 이 처리한다.
 */
@Injectable()
export class TransferService {
  private readonly logger = new Logger(TransferService.name);
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

  /** Step 1 — WaaS NCW transfer/build 호출. 단일 recipient → batch items[1] 로 감싸 전송. */
  async build(
    request: BuildTransferRequestDto,
  ): Promise<BuildTransferResponseDto> {
    const item: Record<string, unknown> = {
      toAddress: request.toAddress,
      amount: request.amount,
      chainId: request.chainId,
    };
    if (request.contractAddress) {
      item.contractAddress = request.contractAddress;
    }
    const body = {
      fromAddress: request.fromAddress,
      items: [item],
      atomic: false,
    };

    try {
      const response = await axios.post(
        `${this.dsrvApiBaseUrl}/waas/api/v1/transactions/ncw/transfer/build`,
        body,
        this.axiosHeaders,
      );

      // WaaS envelope: { requestId, data: { items: [...] } }. Some legacy
      // endpoints may return the payload directly — fallback to response.data.
      const payload = (response.data?.data ?? response.data) as Record<
        string,
        unknown
      >;
      const items = (payload?.items as unknown[]) ?? [];
      if (items.length < 1) {
        this.logger.error(
          `transfer.build:invalid-schema body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'WaaS transfer/build returned empty items[]',
          HttpStatus.BAD_GATEWAY,
        );
      }

      const first = items[0] as Record<string, unknown>;
      const type = first.type as string | undefined;
      const txId = first.batchTxId as string | undefined;
      const messageHash = first.messageHash as string | undefined;
      const transactionId = first.txId as string | undefined;
      const addressSmartAccountId = first.addressSmartAccountId as
        | string
        | undefined;

      if (!type || !txId || !messageHash) {
        this.logger.error(
          `transfer.build:missing-fields body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'WaaS transfer/build response missing batchTxId/messageHash/type',
          HttpStatus.BAD_GATEWAY,
        );
      }

      // MPC sign 의 id 슬롯에 들어갈 값:
      //   TRANSACTION    → transactionId (TX-...)
      //   CONTRACT_CALL  → addressSmartAccountId (EXE-...)
      let signId: string | undefined;
      if (type === 'CONTRACT_CALL') signId = addressSmartAccountId;
      else if (type === 'TRANSACTION') signId = transactionId;
      if (!signId) {
        this.logger.error(
          `transfer.build:missing-signId type=${type} body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          `WaaS transfer/build response missing signId for type=${type}`,
          HttpStatus.BAD_GATEWAY,
        );
      }

      this.logger.log(
        `transfer.build:ok fromAddress=${request.fromAddress} type=${type} txId=${txId}`,
      );
      return { txId, signId, messageHash, type };
    } catch (error) {
      this.throwUpstreamError(error, 'WaaS transfer/build failed');
    }
  }

  /**
   * Step 3 — WaaS NCW broadcast 호출. 응답은 {@code {txHash, status, batchTxId}}.
   *
   * <p>일반 EOA 경로: {@code status=BROADCAST}, {@code txHash} 즉시 발급.
   * <br>EIP-7702 bundler 경로: {@code status=SIGNED}, {@code txHash=null} — bundler 가
   * 비동기 onchain 전송. 호출자는 {@code batchTxId} 로 후속 polling.
   */
  async broadcast(
    request: BroadcastTransferRequestDto,
  ): Promise<BroadcastTransferResponseDto> {
    try {
      const response = await axios.post(
        `${this.dsrvApiBaseUrl}/waas/api/v1/transactions/ncw/${request.txId}/broadcast`,
        {},
        this.axiosHeaders,
      );

      const payload = (response.data?.data ?? response.data) as Record<
        string,
        unknown
      >;
      const txHash = (payload?.txHash as string | null | undefined) ?? null;
      const status = (payload?.status as string | undefined) ?? '';
      // status 누락은 진짜 schema 위반 — txHash 가 null 인 SIGNED 분기와 구분 필요.
      if (!status) {
        this.logger.error(
          `transfer.broadcast:invalid-schema body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'WaaS broadcast response missing status',
          HttpStatus.BAD_GATEWAY,
        );
      }

      this.logger.log(
        `transfer.broadcast:ok batchTxId=${request.txId} status=${status} txHash=${txHash ?? '(pending)'}`,
      );
      return { txHash, status, batchTxId: request.txId };
    } catch (error) {
      this.throwUpstreamError(error, 'WaaS broadcast failed');
    }
  }

  private throwUpstreamError(error: unknown, defaultMsg: string): never {
    if (error instanceof HttpException) throw error;
    if (axios.isAxiosError(error)) {
      const ax = error as AxiosError;
      this.logger.error(
        `transfer.upstream:error status=${ax.response?.status} body=${JSON.stringify(ax.response?.data)}`,
      );
      throw new HttpException(
        (ax.response?.data as object) ?? defaultMsg,
        ax.response?.status ?? HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
    this.logger.error(`transfer.unknown:error ${String(error)}`);
    throw new HttpException(defaultMsg, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
