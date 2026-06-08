import { Body, Controller, Post } from '@nestjs/common';

import { TransferService } from './transfer.service';
import { BuildTransferRequestDto } from './dto/build-transfer-request.dto';
import { BuildTransferResponseDto } from './dto/build-transfer-response.dto';
import { BroadcastTransferRequestDto } from './dto/broadcast-transfer-request.dto';
import { BroadcastTransferResponseDto } from './dto/broadcast-transfer-response.dto';

/**
 * Transfer build / broadcast 진입점 — SDK example 의 두 endpoint.
 *
 * <p>sign 단계는 본 controller 가 다루지 않는다 (SDK 가 디바이스에서 처리).
 */
@Controller('/sdk/transfer')
export class TransferController {
  constructor(private readonly transferService: TransferService) {}

  @Post('/build-hash')
  build(
    @Body() request: BuildTransferRequestDto,
  ): Promise<BuildTransferResponseDto> {
    return this.transferService.build(request);
  }

  @Post('/broadcast')
  broadcast(
    @Body() request: BroadcastTransferRequestDto,
  ): Promise<BroadcastTransferResponseDto> {
    return this.transferService.broadcast(request);
  }
}
