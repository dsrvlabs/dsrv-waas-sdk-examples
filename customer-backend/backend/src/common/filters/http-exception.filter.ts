import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

const HTTP_ERROR_CODES: Record<number, string> = {
  400: 'BAD_REQUEST',
  401: 'UNAUTHORIZED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  422: 'UNPROCESSABLE_ENTITY',
  500: 'INTERNAL_SERVER_ERROR',
  502: 'BAD_GATEWAY',
  503: 'SERVICE_UNAVAILABLE',
};

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    if (exception instanceof HttpException) {
      const exceptionResponse = exception.getResponse();

      // upstream API error: already { requestId, error: { code, message } }
      if (
        typeof exceptionResponse === 'object' &&
        'error' in exceptionResponse &&
        typeof (exceptionResponse as any).error === 'object'
      ) {
        return response.status(status).json(exceptionResponse);
      }

      // internal error (e.g. ValidationPipe): format it
      const res = exceptionResponse as any;
      const message = Array.isArray(res.message)
        ? res.message.join(', ')
        : (res.message ?? exception.message);

      return response.status(status).json({
        error: {
          code: HTTP_ERROR_CODES[status] ?? 'INTERNAL_SERVER_ERROR',
          message,
        },
      });
    }

    response.status(status).json({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Internal server error',
      },
    });
  }
}
