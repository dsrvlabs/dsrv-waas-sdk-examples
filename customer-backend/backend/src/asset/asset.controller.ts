import { Controller, Get, Param, Query } from '@nestjs/common';

import { AssetService } from './asset.service';
import { GetAccountAssetsResponseDto } from './dto/get-account-assets-response.dto';
import { GetLatestValueByChainRequestDto } from './dto/get-latest-value-by-chain-request.dto';
import { LatestValueByChainResponseDto } from './dto/latest-value-by-chain-response.dto';

/**
 * Asset 진입점 — 전송 화면의 자산 드롭다운/잔액/법정통화 환산값 표시용 endpoint.
 *
 * <p>{@code GET /sdk/asset/accounts/{accountId}}
 * — WaaS 계정 자산 목록(계정의 모든 주소 잔고를 chain·asset 단위로 합산)을 전체 조회.
 * userId·addressId 불필요(projectId(passport) + accountId 스코핑).
 *
 * <p>{@code GET /sdk/asset/by-chain/latest-value?chainId=&contractAddress=&currency=&amount=}
 * — price-hub 로 중계해 자산별 symbol/decimals/단가/환산값을 조회. contractAddress 생략 시 native.
 */
@Controller('/sdk/asset')
export class AssetController {
  constructor(private readonly assetService: AssetService) {}

  @Get('/accounts/:accountId')
  getAccountAssets(
    @Param('accountId') accountId: string,
  ): Promise<GetAccountAssetsResponseDto> {
    return this.assetService.getAccountAssetList(accountId);
  }

  @Get('/by-chain/latest-value')
  getLatestValueByChain(
    @Query() request: GetLatestValueByChainRequestDto,
  ): Promise<LatestValueByChainResponseDto> {
    return this.assetService.getLatestValueByChain(request);
  }
}
