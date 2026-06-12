import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * 모든 응답 에러를 SDK 가 기대하는 envelope 형식으로 통일한다.
 *
 *   { "requestId": "...", "error": { "code": "...", "message": "..." } }
 *
 * 인식하는 upstream 형식:
 *   1) Auth / WaaS envelope: { requestId, error: { code, message } } → 그대로 forward
 *   2) Stablecoin flat:      { statusCode, timestamp, path, message } → 변환
 *   3) NestJS HttpException (ValidationPipe / 자체 throw 등) → 변환
 *   4) 그 외 unknown error → 500 INTERNAL_ERROR
 *
 * SDK 의 HttpUtil.unwrapApiResponse 가 `error` 또는 `data` 키가 없으면
 * "Response envelope missing both 'error' and 'data' fields" 라는 모호한 메시지로
 * 진짜 에러 원인을 가린다. 이 filter 가 그것을 방지한다.
 */

const HTTP_ERROR_CODES: Record<number, string> = {
  400: 'BAD_REQUEST',
  401: 'UNAUTHORIZED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  422: 'UNPROCESSABLE_ENTITY',
  429: 'RATE_LIMIT_EXCEEDED',
  500: 'INTERNAL_SERVER_ERROR',
  502: 'BAD_GATEWAY',
  503: 'SERVICE_UNAVAILABLE',
};

interface SdkEnvelopeError {
  requestId: string;
  error: { code: string; message: string };
}

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const requestId = resolveRequestId(request);

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    if (exception instanceof HttpException) {
      const body = exception.getResponse();
      const envelope = toSdkEnvelope(body, status, requestId);
      return response.status(status).json(envelope);
    }

    // 알 수 없는 throw — 외부 응답엔 고정 generic 메시지만 노출 (DB host, SQL 쿼리,
    // 내부 경로, upstream URL 등 원본 message 의 내부 정보 누출 방지).
    // 상세 message + stack 은 서버 로그에만 남기고, requestId 로 클라이언트가 서버 로그를
    // 매칭할 수 있게 한다.
    if (exception instanceof Error) {
      this.logger.error(
        `[requestId=${requestId || '(none)'}] ${exception.name}: ${exception.message}`,
        exception.stack,
      );
    } else {
      this.logger.error(
        `[requestId=${requestId || '(none)'}] Non-Error throw: ${String(exception)}`,
      );
    }

    return response.status(status).json({
      requestId,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Internal server error',
      },
    } satisfies SdkEnvelopeError);
  }
}

/**
 * 어떤 upstream 형식이든 SDK envelope 으로 변환.
 * - 객체가 이미 { error: { code, message } } 형태면 그대로 forward (Auth/WaaS)
 * - { statusCode, message } 형태면 stablecoin/NestJS 형식으로 간주하고 변환
 * - 그 외는 message 만 추출
 */
function toSdkEnvelope(
  body: unknown,
  status: number,
  fallbackRequestId: string,
): SdkEnvelopeError {
  // string body (NestJS HttpException(message: string) 케이스)
  if (typeof body === 'string') {
    return {
      requestId: fallbackRequestId,
      error: {
        code: HTTP_ERROR_CODES[status] ?? 'INTERNAL_SERVER_ERROR',
        message: body,
      },
    };
  }

  if (typeof body !== 'object' || body === null) {
    return {
      requestId: fallbackRequestId,
      error: {
        code: HTTP_ERROR_CODES[status] ?? 'INTERNAL_SERVER_ERROR',
        message: String(body ?? 'Unknown error'),
      },
    };
  }

  const obj = body as Record<string, unknown>;

  // Auth / WaaS envelope: { requestId, error: { code, message } } → 그대로 forward
  if (
    obj.error &&
    typeof obj.error === 'object' &&
    !Array.isArray(obj.error) &&
    'code' in (obj.error as Record<string, unknown>) &&
    'message' in (obj.error as Record<string, unknown>)
  ) {
    const upstreamError = obj.error as Record<string, unknown>;
    return {
      requestId: (obj.requestId as string) ?? fallbackRequestId,
      error: {
        code: String(upstreamError.code),
        message: String(upstreamError.message),
      },
    };
  }

  // ValidationPipe 의 errors[] (Array<string>) — NestJS 가 message 를 배열로 만드는 케이스
  const message = Array.isArray(obj.message)
    ? (obj.message as unknown[]).join(', ')
    : (obj.message as string | undefined);

  // Stablecoin flat: { statusCode, timestamp, path, message } 또는
  // NestJS 의 HttpException default: { statusCode, message, error: "Forbidden" }
  if (typeof obj.statusCode === 'number' && message) {
    return {
      requestId: fallbackRequestId,
      error: {
        code: HTTP_ERROR_CODES[obj.statusCode] ?? `HTTP_${obj.statusCode}`,
        message,
      },
    };
  }

  // 그 외 — message 만이라도 살림
  return {
    requestId: fallbackRequestId,
    error: {
      code: HTTP_ERROR_CODES[status] ?? 'INTERNAL_SERVER_ERROR',
      message:
        message ??
        (typeof obj.error === 'string' ? (obj.error as string) : 'Unknown error'),
    },
  };
}

/**
 * upstream 의 trace id 또는 새로 생성된 id 를 requestId 로 사용.
 * Gateway 가 보낸 X-Trace-Id / X-Request-Id 헤더를 우선 사용.
 */
function resolveRequestId(req: Request): string {
  const candidates = [
    req.headers['x-trace-id'],
    req.headers['x-request-id'],
    req.headers['traceparent'],
  ];
  for (const v of candidates) {
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return '';
}
