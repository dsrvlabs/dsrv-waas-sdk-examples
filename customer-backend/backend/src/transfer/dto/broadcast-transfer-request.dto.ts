import { IsNotEmpty, IsString } from 'class-validator';

/**
 * Transfer broadcast 요청 — SIGNED 트랜잭션을 체인에 브로드캐스트.
 *
 * <p>build 단계에서 받은 {@code txId} (batchTxId) 를 그대로 다시 보내면,
 * customer-backend 가 WaaS 의 {@code POST /api/v1/transactions/ncw/{batchTxId}/broadcast}
 * 를 호출한다.
 */
export class BroadcastTransferRequestDto {
  /** build 응답의 txId (BTX-...). */
  @IsString()
  @IsNotEmpty()
  txId!: string;
}
