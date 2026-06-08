import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import * as os from 'os';

function getLocalIpv4(): string {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    const entries = interfaces[name] ?? [];
    for (const entry of entries) {
      if (entry.family === 'IPv4' && !entry.internal) {
        return entry.address;
      }
    }
  }
  return '127.0.0.1';
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  // whitelist 옵션은 DTO 필드에 class-validator 데코레이터가 있을 때만 의미가 있음.
  // 모든 request DTO 는 class-validator 데코레이터로 검증. whitelist 활성화 시
  // 데코레이터 없는 필드가 strip 되어 미정의 페이로드가 거부됨 — 추후 필요 시 켜기.
  app.useGlobalPipes(new ValidationPipe());
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new LoggingInterceptor());

  const port = process.env.PORT || 3000;
  await app.listen(port);

  // 어느 DSRV Gateway 를 보는지 확인용 — 배포 환경에서도 항상 출력
  console.log(`DSRV_API_BASE_URL: ${process.env.DSRV_API_BASE_URL ?? ''}`);

  // 나머지 접속 정보는 로컬 실행 시에만 출력 (배포 환경은 NODE_ENV=production)
  if (process.env.NODE_ENV !== 'production') {
    const basePath = '/';
    const localIp = getLocalIpv4();
    console.log(`PORT: ${port}`);
    console.log(`Local server IP: ${localIp}`);
    console.log(`Endpoint base path: ${basePath}`);
    console.log(`Application is running on http://${localIp}:${port}${basePath}`);
  }
}
bootstrap();
