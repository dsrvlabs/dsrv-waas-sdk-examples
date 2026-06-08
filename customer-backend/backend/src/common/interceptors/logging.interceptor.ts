import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

const HEALTH_CHECK_PATH = '/api/health';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger('HTTP');

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const response = context.switchToHttp().getResponse();
    const { method, url, ip, body } = request;
    const userAgent = request.get('user-agent') || '';
    const startTime = Date.now();

    const isHealthCheck = url.startsWith(HEALTH_CHECK_PATH);

    // Debug 레벨로 request body 로깅
    if (body && Object.keys(body).length > 0) {
      this.logger.debug(
        `<<< IN  ${method} ${url}\n${JSON.stringify(body, null, 2)}\n---`,
      );
    }

    return next.handle().pipe(
      tap({
        next: () => {
          if (isHealthCheck) {
            return;
          }
          const { statusCode } = response;
          const responseTime = Date.now() - startTime;

          this.logger.log(
            `${method} ${url} ${statusCode} ${responseTime}ms - ${ip} - ${userAgent}`,
          );
        },
        error: (error) => {
          const statusCode = error.status || 500;
          const responseTime = Date.now() - startTime;

          this.logger.error(
            `${method} ${url} ${statusCode} ${responseTime}ms - ${ip} - ${userAgent}`,
            error.stack,
          );

          // 에러 발생 시에도 body 정보 debug 로깅
          if (body && Object.keys(body).length > 0) {
            this.logger.debug(
              `<<< IN ERROR  ${method} ${url}\n${JSON.stringify(body, null, 2)}\n---`,
            );
          }
        },
      }),
    );
  }
}
