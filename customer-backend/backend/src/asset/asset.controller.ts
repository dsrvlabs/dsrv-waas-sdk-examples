import { Controller, Get, Query } from '@nestjs/common';

import { AssetService } from './asset.service';
import { GetLatestValueByChainRequestDto } from './dto/get-latest-value-by-chain-request.dto';
import { LatestValueByChainResponseDto } from './dto/latest-value-by-chain-response.dto';

/**
 * Asset 가치 조회 진입점 — 전송 화면이 보유 토큰의 법정통화 환산값을 표시하기 위한 endpoint.
 *
 * <p>{@code GET /sdk/asset/by-chain/latest-value?chainId=&contractAddress=&currency=&amount=}
 * — price-hub 의 동일 endpoint 로 중계한다. contractAddress 생략 시 해당 체인 native 토큰을 조회.
 */
@Controller('/sdk/asset')
export class AssetController {
  constructor(private readonly assetService: AssetService) {}

  @Get('/by-chain/latest-value')
  getLatestValueByChain(
    @Query() request: GetLatestValueByChainRequestDto,
  ): Promise<LatestValueByChainResponseDto> {
    return this.assetService.getLatestValueByChain(request);
  }
}
