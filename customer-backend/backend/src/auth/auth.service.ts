import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { AuthenticateDto } from './dto/authenticate.dto';

/**
 * SDK 등록 proxy — DSRV Auth service ({@code /auth/api/v1/sdk/registration}) 호출 대행.
 *
 * <p>인증: customer-backend 가 자체 {@code x-api-key (X_API_KEY)} 로 DSRV Gateway 호출.
 * Gateway 가 {@code x-api-key → X-User-Passport JWT} 변환 후 Auth service 에 전달.
 */
@Injectable()
export class AuthService {
  private readonly dsrvApiBaseUrl: string;
  private readonly apiKey: string;

  constructor(private configService: ConfigService) {
    this.dsrvApiBaseUrl = this.configService.getOrThrow<string>(
      'DSRV_API_BASE_URL',
    );
    this.apiKey = this.configService.getOrThrow<string>('X_API_KEY');
  }

  private get axiosHeaders() {
    return {
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this.apiKey,
      },
    };
  }
  async authenticate(request: AuthenticateDto) {
    try {
      const response = await axios.post(
        `${this.dsrvApiBaseUrl}/auth/api/v1/sdk/registration`,
        {
          sdkId: request.sdkId,
          appId: request.appId,
          userCredential: request.userCredential,
          ...(request.signingHash && { signingHash: request.signingHash }),
          deviceInfo: request.deviceInfo,
        },
        this.axiosHeaders,
      );

      return response.data;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new HttpException(
          error.response?.data || 'Failed to initialize user',
          error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
        );
      }
      throw new HttpException(
        'Failed to authenticate',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}
