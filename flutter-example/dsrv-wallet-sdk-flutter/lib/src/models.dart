/// Data models — native DSRVWallet SDK 와 1:1.
///
/// 모든 모델은 MethodChannel 직렬화(Map/List/기본형) 와의 변환을 위해
/// `fromMap` 팩토리를 제공한다.

/// MPC 키 생성 결과.
class KeyCreateResult {
  final String publicKey; // 0x04-prefixed uncompressed
  final String address; // 0x-prefixed EVM 주소

  const KeyCreateResult({required this.publicKey, required this.address});

  factory KeyCreateResult.fromMap(Map<dynamic, dynamic> map) => KeyCreateResult(
        publicKey: map['publicKey'] as String,
        address: map['address'] as String,
      );
}

/// 체인 트랜잭션 해시.
class TxHashResult {
  final String txHash; // 0x-prefixed

  const TxHashResult({required this.txHash});

  factory TxHashResult.fromMap(Map<dynamic, dynamic> map) =>
      TxHashResult(txHash: map['txHash'] as String);
}

/// Bulk operation (approve / delegate / revoke) 의 chain 별 결과. server 가 결정한 chain 목록 각각에
/// 대해 sign + submit 을 시도한 outcome 을 표현 (서버 응답의 outcome 과 1:1 대응).
///
/// [outcome] 값:
/// - `NEW` (delegate) / `BUILT` (approve) — 신규 빌드 + sign + submit 성공. [txHash] non-null.
/// - `RESUMED` (delegate) — 이전 broadcast 실패로 보관된 SIGNED 재사용, 재 broadcast 성공. [txHash] non-null.
/// - `ALREADY_DELEGATED` (delegate) — 이미 위임된 chain. 추가 처리 불필요. [txHash] null.
/// - `SKIPPED` (approve) — 대상 token 없음. [txHash] null.
/// - `FAILED` — 서버 빌드 또는 SDK sign/submit 실패. [errorMessage] non-null.
///
/// [isSuccess] 는 모든 non-FAILED 케이스를 성공으로 처리한다 — caller 는 `list.every((r) => r.isSuccess)`
/// 로 전체 성공 여부 확인 가능.
///
/// 외부 호출 자체가 실패해서 0 chain 시도된 경우는 [WalletResult.failure] 로 surface 되며 이 타입의
/// list 안에는 등장하지 않음.
class ChainTxResult {
  final String chainId;
  final String outcome;
  final String? txHash;
  final String? errorMessage;

  const ChainTxResult({
    required this.chainId,
    required this.outcome,
    this.txHash,
    this.errorMessage,
  });

  bool get isSuccess => outcome != 'FAILED';

  factory ChainTxResult.fromMap(Map<dynamic, dynamic> map) => ChainTxResult(
        chainId: map['chainId'] as String,
        outcome: map['outcome'] as String,
        txHash: map['txHash'] as String?,
        errorMessage: map['errorMessage'] as String?,
      );
}

/// buildTx 결과 — sign / broadcastTx 호출에 필요한 필드들.
class TxBuildResult {
  /// broadcast 시 path 파라미터로 쓰이는 batch tx id (BTX-...).
  final String txId;

  /// MPC sign 의 id 슬롯에 들어갈 값.
  /// TRANSACTION 이면 transactionId (TX-...), CONTRACT_CALL 이면 addressSmartAccountId (EXE-...).
  /// `sign` 다단계 호출 시 [txId] 가 아닌 이 값을 넘겨야 한다.
  final String signId;

  /// 서명 대상 keccak256 hash (0x-prefixed).
  final String messageHash;

  /// 서명 대상 message 종류 — TRANSACTION | CONTRACT_CALL.
  final String type;

  const TxBuildResult({
    required this.txId,
    required this.signId,
    required this.messageHash,
    required this.type,
  });

  factory TxBuildResult.fromMap(Map<dynamic, dynamic> map) => TxBuildResult(
        txId: map['txId'] as String,
        signId: map['signId'] as String,
        messageHash: map['messageHash'] as String,
        type: map['type'] as String,
      );
}

/// MPC sign 결과 — r, s, v.
class SignResult {
  final String r;
  final String s;
  final int v;

  const SignResult({required this.r, required this.s, required this.v});

  factory SignResult.fromMap(Map<dynamic, dynamic> map) => SignResult(
        r: map['r'] as String,
        s: map['s'] as String,
        v: (map['v'] as num).toInt(),
      );
}

/// restore() 의 지갑별 복원 결과.
class RestoredKey {
  final String address;
  final bool success;
  final String? error;

  const RestoredKey({required this.address, required this.success, this.error});

  factory RestoredKey.fromMap(Map<dynamic, dynamic> map) => RestoredKey(
        address: map['address'] as String,
        success: map['success'] as bool,
        error: map['error'] as String?,
      );
}

/// account 생성 결과.
class AccountResult {
  final String accountId;
  final String label;

  const AccountResult({required this.accountId, required this.label});

  factory AccountResult.fromMap(Map<dynamic, dynamic> map) => AccountResult(
        accountId: map['accountId'] as String,
        label: map['label'] as String,
      );
}

/// account 정보 (등록된 address 목록 포함).
class AccountInfo {
  final String accountId;
  final String label;
  final List<AddressInfo> addresses;

  const AccountInfo({
    required this.accountId,
    required this.label,
    this.addresses = const [],
  });

  factory AccountInfo.fromMap(Map<dynamic, dynamic> map) => AccountInfo(
        accountId: map['accountId'] as String,
        label: map['label'] as String,
        addresses: ((map['addresses'] as List?) ?? const [])
            .map((e) => AddressInfo.fromMap(e as Map))
            .toList(),
      );
}

/// 등록된 address 정보.
class AddressInfo {
  final String accountId;
  final String addressId;
  final String address; // 0x-prefixed EVM 주소
  final String publicKey; // 0x04-prefixed uncompressed
  final String? label;
  final String chainType; // "EVM" 등

  const AddressInfo({
    required this.accountId,
    required this.addressId,
    required this.address,
    required this.publicKey,
    this.label,
    required this.chainType,
  });

  factory AddressInfo.fromMap(Map<dynamic, dynamic> map) => AddressInfo(
        accountId: map['accountId'] as String,
        addressId: map['addressId'] as String,
        address: map['address'] as String,
        publicKey: map['publicKey'] as String,
        label: map['label'] as String?,
        chainType: map['chainType'] as String,
      );
}

/// 지원 체인 정보.
class ChainInfo {
  final String chainId;
  final String name;
  final String chainType; // "EVM" 등
  final String networkType; // "MAINNET" / "TESTNET"

  const ChainInfo({
    required this.chainId,
    required this.name,
    required this.chainType,
    required this.networkType,
  });

  factory ChainInfo.fromMap(Map<dynamic, dynamic> map) => ChainInfo(
        chainId: map['chainId'] as String,
        name: map['name'] as String,
        chainType: map['chainType'] as String,
        networkType: map['networkType'] as String,
      );
}

/// 전송 자산 유형.
sealed class TransferAsset {
  const TransferAsset();

  /// 체인 기본 코인 (ETH, MATIC 등).
  const factory TransferAsset.native() = NativeAsset;

  /// ERC-20 토큰.
  const factory TransferAsset.erc20(String tokenAddress) = Erc20Asset;

  /// MethodChannel 전송용 Map.
  Map<String, dynamic> toMap();
}

class NativeAsset extends TransferAsset {
  const NativeAsset();

  @override
  Map<String, dynamic> toMap() => {'type': 'native'};
}

class Erc20Asset extends TransferAsset {
  final String tokenAddress;
  const Erc20Asset(this.tokenAddress);

  @override
  Map<String, dynamic> toMap() =>
      {'type': 'erc20', 'tokenAddress': tokenAddress};
}
