import { HttpException, HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';
import { SigningKey } from 'ethers';

import { PaymentRequestDto } from './dto/payment-request.dto';
import { PaymentResponseDto } from './dto/payment-response.dto';
import { QuoteResponseDto } from './dto/quote-response.dto';

/**
 * Topup 결제 흐름 service — Payments(stablecoin) 서버 프록시 + 고객사 서명.
 *
 * <p>{@link PaymentService.pay} 단일 진입점에서 세 단계를 순차 처리한다:
 * <ol>
 *   <li>quote → Payments {@code POST /api/transactions/quote}
 *       (paymentDigest + params 수신)</li>
 *   <li>sign → paymentDigest 를 고객사 개인키({@code CUSTOMER_PRIVATE_KEY})로 ECDSA 서명</li>
 *   <li>execute → Payments {@code POST /api/transactions} (TOPUP, signature 첨부)</li>
 * </ol>
 *
 * <p>인증: customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 DSRV Gateway 호출.
 * Gateway 가 {@code x-api-key → X-User-Passport JWT} 변환 후 Payments 에 전달
 * (WaaS 와 동일 패턴 — base URL 공유).
 *
 * <p><b>단위 boundary</b>: amount 는 humanized BigDecimal 문자열 (예: "1.5" = 1.5 USDC).
 * customer-backend 는 변환 없이 그대로 stablecoin 에 forward. raw smallest-unit 변환은
 * stablecoin 내부에서 token decimals 적용해 처리. feeAllocations[].amount 는 예외 —
 * stablecoin quote 응답의 raw BigInteger 를 그대로 echo (컨트랙트 keccak 검증 대상).
 */
@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);
  private readonly dsrvApiBaseUrl: string;
  private readonly apiKey: string;
  private readonly signingKey: SigningKey;

  constructor(private readonly configService: ConfigService) {
    this.dsrvApiBaseUrl = this.configService.getOrThrow<string>(
      'DSRV_API_BASE_URL',
    );
    this.apiKey = this.configService.getOrThrow<string>('X_API_KEY');
    // 고객사 EOA 개인키 — paymentDigest 서명 전용. 부팅 시 1회 로드.
    // ethers SigningKey 는 0x-prefixed 32바이트 hex 를 요구 — .env 값에 0x 가 없어도 허용.
    const rawKey = this.configService
      .getOrThrow<string>('CUSTOMER_PRIVATE_KEY')
      .trim();
    this.signingKey = new SigningKey(
      rawKey.startsWith('0x') ? rawKey : `0x${rawKey}`,
    );
  }

  private get axiosHeaders() {
    // Gateway 경유 모드: X_API_KEY 를 x-api-key 로 전달하면 Gateway 가
    // X-User-Passport JWT 로 변환해 Payments 에 전달.
    //
    // transformRequest 로 직렬화 후 헤더 강제 override — axios 가 자동으로
    // `application/json;charset=utf-8` 박는 동작 차단 (stablecoin Spring 이 거절).
    return {
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
      },
      transformRequest: [
        (data: unknown, headers: Record<string, string>) => {
          headers['Content-Type'] = 'application/json';
          return JSON.stringify(data);
        },
      ],
    };
  }

  /**
   * Topup 결제 단일 흐름: quote → sign → execute.
   */
  async pay(request: PaymentRequestDto): Promise<PaymentResponseDto> {
    const quote = await this.quote(request);
    const signature = this.sign(quote.paymentDigest);
    return this.execute(request, quote, signature);
  }

  /** Step 1 — Payments quote 호출, paymentDigest + params 수신. */
  private async quote(request: PaymentRequestDto): Promise<QuoteResponseDto> {
    try {
      const response = await axios.post(
        `${this.dsrvApiBaseUrl}/payments/api/transactions/quote`,
        {
          chainId: request.chainId,
          token: request.token,
          payer: request.from,
          to: request.to,
          amount: request.amount,
          paymentType: request.paymentType,
        },
        this.axiosHeaders,
      );

      const data = this.unwrapEnvelope<QuoteResponseDto>(
        response.data,
        'Payments quote failed',
      );
      // 성공 응답 스키마 검증 — 서명/execute 가 의존하는 필수 필드.
      if (
        !data?.paymentDigest ||
        !data?.params?.paymentUuid ||
        data?.params?.deadline == null
      ) {
        this.logger.error(
          `payments.quote:invalid-schema body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'Payments quote returned an invalid response',
          HttpStatus.BAD_GATEWAY,
        );
      }
      this.logger.log(
        `payments.quote:ok payer=${request.from} amountHumanized=${request.amount} paymentUuid=${data.params.paymentUuid} deadline=${data.params.deadline}`,
      );
      return data;
    } catch (error) {
      this.throwUpstreamError(error, 'Payments quote failed');
    }
  }

  /**
   * Step 2 — paymentDigest 를 고객사 개인키로 ECDSA 서명.
   *
   * <p>paymentDigest 는 이미 EIP-712 최종 다이제스트(32 bytes)이므로 추가 해시 없이 직접 서명한다.
   * 반환 형식: "0x" + r(64) + s(64) + v(2) = 132 chars (v = 27/28).
   */
  private sign(paymentDigest: string): string {
    const signature = this.signingKey.sign(paymentDigest).serialized;
    this.logger.log(`payments.sign:ok digest=${paymentDigest}`);
    return signature;
  }

  /** Step 3 — Payments transaction 생성 (TOPUP), 서명 첨부. */
  private async execute(
    request: PaymentRequestDto,
    quote: QuoteResponseDto,
    signature: string,
  ): Promise<PaymentResponseDto> {
    try {
      const params = quote.params;
      // Payments stablecoin transaction create — TOPUP 분기는 paymentType=TOPUP 으로 트리거.
      //
      // stablecoin 측이 quote 시점에 발급한 값(paymentUuid/customerEpoch/deadline/maxFeeAmount)을 권위로 사용.
      // chainId/token/feeAllocations 등 stablecoin 이 자체 도출하거나 사용하지 않는 필드는 전송하지 않는다
      // (CreateTransactionRequest 가 ignoreUnknown=false 라 무관 필드는 400 으로 거부됨).
      const body = {
        paymentType: 'TOPUP',
        sourceUserId: request.sourceUserId,
        source: {
          paymentRail: 'EVM',
          fromAddress: request.from,
          currency: 'USDC',
        },
        destination: {
          paymentRail: 'EVM',
          toAddress: request.to,
          currency: 'USDC',
        },
        amount: request.amount,
        onchainPayment: {
          paymentUuid: params.paymentUuid,
          deadline: params.deadline,
          customerEpoch: params.customerEpoch,
          onchainPaymentType: request.paymentType,
        },
        feeAllocationsHash: params.feeAllocationsHash,
        feeAllocations: params.feeAllocations,
        signature,
      };

      const response = await axios.post(
        `${this.dsrvApiBaseUrl}/payments/api/transactions`,
        body,
        this.axiosHeaders,
      );

      const data = this.unwrapEnvelope<PaymentResponseDto>(
        response.data,
        'Payments execute failed',
      );
      // 성공 응답 스키마 검증 — transactionId/status 없으면 실패로 간주.
      if (!data?.transactionId || !data?.status) {
        this.logger.error(
          `payments.execute:invalid-schema body=${JSON.stringify(response.data)}`,
        );
        throw new HttpException(
          'Payments execute returned an invalid response',
          HttpStatus.BAD_GATEWAY,
        );
      }
      this.logger.log(
        `payments.execute:ok paymentUuid=${params.paymentUuid} txHash=${data.txHash} status=${data.status}`,
      );
      return {
        transactionId: data.transactionId,
        paymentUuid: params.paymentUuid,
        status: data.status,
        txHash: data.txHash,
        submittedAt: data.submittedAt,
      };
    } catch (error) {
      this.throwUpstreamError(error, 'Payments execute failed');
    }
  }

  /**
   * Payments API envelope({@code { data, error }}) 해제.
   *
   * <p>HTTP 200 이라도 {@code error} 가 존재하면 upstream 실패로 간주해 예외를 던진다.
   * envelope 형태가 아니면(레거시/직접 페이로드) body 를 그대로 반환한다.
   */
  private unwrapEnvelope<T>(body: unknown, defaultMsg: string): T {
    if (body && typeof body === 'object') {
      const envelope = body as { data?: unknown; error?: unknown };
      if (envelope.error != null && envelope.error !== false) {
        this.logger.error(
          `payments.envelope:error error=${JSON.stringify(envelope.error)}`,
        );
        throw new HttpException(
          (typeof envelope.error === 'object'
            ? (envelope.error as object)
            : { message: String(envelope.error) }) ?? defaultMsg,
          HttpStatus.BAD_GATEWAY,
        );
      }
      if ('data' in envelope) {
        return envelope.data as T;
      }
    }
    return body as T;
  }

  private throwUpstreamError(error: unknown, defaultMsg: string): never {
    // 내부 검증(invalid-schema 등)에서 던진 HttpException 은 그대로 전파.
    if (error instanceof HttpException) {
      throw error;
    }
    if (axios.isAxiosError(error)) {
      const ax = error as AxiosError;
      this.logger.error(
        `payments.upstream:error status=${ax.response?.status} body=${JSON.stringify(ax.response?.data)}`,
      );
      throw new HttpException(
        (ax.response?.data as object) ?? defaultMsg,
        ax.response?.status ?? HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
    this.logger.error(`payments.unknown:error ${String(error)}`);
    throw new HttpException(defaultMsg, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
