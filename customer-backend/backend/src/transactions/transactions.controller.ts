import { Controller, Get, Query } from '@nestjs/common';

import { TransactionsService } from './transactions.service';
import { GetTransactionsRequestDto } from './dto/get-transactions-request.dto';
import { GetTransactionsResponseDto } from './dto/get-transactions-response.dto';

/**
 * Transaction history 진입점 — SDK example 의 거래 내역 조회 endpoint.
 *
 * <p>{@code GET /sdk/transactions?userId=...&accountId=...&chainId=&page=&limit=}
 */
@Controller('/sdk/transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Get()
  getTransactions(
    @Query() request: GetTransactionsRequestDto,
  ): Promise<GetTransactionsResponseDto> {
    return this.transactionsService.getTransactions(request);
  }
}
