import { Body, Controller, Post } from '@nestjs/common';

import { PaymentService } from './payment.service';
import { PaymentRequestDto } from './dto/payment-request.dto';
import { PaymentResponseDto } from './dto/payment-response.dto';

/**
 * Topup 결제 흐름 controller — RN 앱 진입점.
 *
 * <p>{@code POST /payments} 단일 엔드포인트. 내부에서 quote → paymentDigest 서명(고객사 PK)
 * → execute 를 순차 처리하므로 클라이언트는 서명을 첨부하지 않는다.
 */
@Controller('/payments')
export class PaymentController {
  constructor(private readonly paymentService: PaymentService) {}

  @Post()
  async pay(@Body() request: PaymentRequestDto): Promise<PaymentResponseDto> {
    return this.paymentService.pay(request);
  }
}
