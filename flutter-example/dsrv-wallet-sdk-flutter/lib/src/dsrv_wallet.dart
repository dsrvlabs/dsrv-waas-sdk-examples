import 'handlers.dart';
import 'models.dart';
import 'wallet_error.dart';
import 'wallet_result.dart';
import 'internal/native_bridge.dart';

/// DSRV Wallet SDK — Flutter public API.
///
/// 모든 동작은 native `DSRVWallet` SDK(Android AAR / iOS framework)에
/// MethodChannel 로 위임된다. (백업/Passkey/생체인증/MPC = native 그대로)
class DSRVWallet {
  DSRVWallet._();

  /// SDK 초기화 및 인증.
  ///
  /// [authHandler] 는 native 가 challenge 를 요청할 때 역방향 호출된다.
  static Future<WalletResult<void>> initialize({
    required String sdkId,
    required UserCredential userCredential,
    required AuthHandler authHandler,
    required String baseUrl,
  }) async {
    NativeBridge.setAuthHandler(authHandler);
    return _guard(() async {
      await NativeBridge.invoke<void>('initialize', {
        'sdkId': sdkId,
        'credentialType': userCredential.type.wireValue,
        'credentialValue': userCredential.value,
        'provider': userCredential.provider,
        'baseUrl': baseUrl,
      });
      return null;
    });
  }

  static Future<bool> get isInitialized async =>
      (await NativeBridge.invoke<bool>('isInitialized')) ?? false;

  /// 현재 사용자 세션을 종료해 다음 [initialize] 가 **다른 [UserCredential]** 로 새로 인증되게
  /// 합니다. 사용자 전환(로그아웃 → 다른 사용자로 로그인) 의 진입점입니다.
  ///
  /// 동작:
  /// - 내부 initialized 플래그를 false 로 되돌려 다음 [initialize] 가 idempotent 가드를
  ///   통과하도록 합니다.
  /// - 로컬 DB (key share / account / pending backup / tokens) 와 백업 상태는 **유지** —
  ///   같은 사용자로 다시 init 하면 기존 지갑/토큰을 그대로 재사용합니다.
  ///
  /// 호출 후 반드시 새 [UserCredential] 로 [initialize] 를 다시 호출하세요.
  static Future<void> reset() async {
    await NativeBridge.invoke<void>('reset');
  }

  /// account 생성 (서버 idempotent).
  static Future<WalletResult<AccountResult>> createAccount(
      {required String label}) {
    return _guard(() async {
      final map = await NativeBridge.invokeMap('createAccount', {'label': label});
      return AccountResult.fromMap(map!);
    });
  }

  /// 서버에서 account 목록 조회.
  static Future<WalletResult<List<AccountInfo>>> getAccountList() {
    return _guard(() async {
      final list = await NativeBridge.invokeList('getAccountList');
      return (list ?? const [])
          .map((e) => AccountInfo.fromMap(e as Map))
          .toList();
    });
  }

  /// 지원 체인 목록 조회.
  static Future<WalletResult<List<ChainInfo>>> getChainList() {
    return _guard(() async {
      final list = await NativeBridge.invokeList('getChainList');
      return (list ?? const [])
          .map((e) => ChainInfo.fromMap(e as Map))
          .toList();
    });
  }

  /// MPC 키 생성 + WaaS 주소 등록.
  ///
  /// [accountId] 는 [getAccountList] / [createAccount] 의 결과에서 받습니다.
  static Future<WalletResult<KeyCreateResult>> createAddress({
    required String accountId,
    required String chainType,
    String? label,
  }) {
    return _guard(() async {
      final map = await NativeBridge.invokeMap('createAddress', {
        'accountId': accountId,
        'chainType': chainType,
        'label': label,
      });
      return KeyCreateResult.fromMap(map!);
    });
  }

  /// 전송 원샷 (build hash → MPC sign → broadcast).
  ///
  /// [amount] 는 base units 의 10진 문자열 (Wei 등).
  static Future<WalletResult<TxHashResult>> transfer({
    required String address,
    required String chainId,
    required TransferAsset asset,
    required String recipient,
    required String amount,
  }) {
    return _guard(() async {
      final map = await NativeBridge.invokeMap('transfer', {
        'address': address,
        'chainId': chainId,
        'asset': asset.toMap(),
        'recipient': recipient,
        'amount': amount,
      });
      return TxHashResult.fromMap(map!);
    });
  }

  /// 전송 트랜잭션을 빌드한다 — 서명 대상 hash 를 반환 (transfer 단계별 흐름의 1단계).
  ///
  /// [amount] 는 base units 의 10진 문자열 (Wei 등).
  static Future<WalletResult<TxBuildResult>> buildTx({
    required String address,
    required String chainId,
    required TransferAsset asset,
    required String recipient,
    required String amount,
  }) {
    return _guard(() async {
      final map = await NativeBridge.invokeMap('buildTx', {
        'address': address,
        'chainId': chainId,
        'asset': asset.toMap(),
        'recipient': recipient,
        'amount': amount,
      });
      return TxBuildResult.fromMap(map!);
    });
  }

  /// SIGNED 트랜잭션을 체인에 브로드캐스트 (transfer 단계별 흐름의 3단계).
  ///
  /// [txId] 는 [buildTx] 응답의 `txId` (broadcast 용 batch id).
  static Future<WalletResult<TxHashResult>> broadcastTx({
    required String address,
    required String txId,
  }) {
    return _guard(() async {
      final map = await NativeBridge.invokeMap('broadcastTx', {
        'address': address,
        'txId': txId,
      });
      return TxHashResult.fromMap(map!);
    });
  }

  /// 해시된 메시지에 MPC 서명을 수행한다 (transfer 단계별 흐름의 2단계).
  ///
  /// [hashedMessage] / [signId] / [messageType] 은 모두 `buildTx` 응답에서 그대로 가져온다.
  /// customer-backend 가 build/broadcast 만 proxy 하고 sign 은 SDK 가 직접 수행하는 흐름에서 사용.
  static Future<WalletResult<SignResult>> sign({
    required String address,
    required String hashedMessage,
    required String signId,
    required String messageType,
  }) {
    return _guard(() async {
      final map = await NativeBridge.invokeMap('sign', {
        'address': address,
        'hashedMessage': hashedMessage,
        'signId': signId,
        'messageType': messageType,
      });
      return SignResult.fromMap(map!);
    });
  }

  /// EIP-7702 위임 — 지원 chain 일괄 처리. 결과는 chain 별 [ChainTxResult] 목록 (성공/실패 모두 포함).
  /// 일부 chain 만 실패해도 [WalletResult.success] 로 반환되며 각 item 의 [ChainTxResult.isSuccess] 로 분기.
  static Future<WalletResult<List<ChainTxResult>>> delegate(
      {required String address}) {
    return _guard(() async {
      final list = await NativeBridge.invokeList('delegate', {'address': address});
      return (list ?? const [])
          .map((e) => ChainTxResult.fromMap(e as Map))
          .toList();
    });
  }

  /// EIP-7702 위임 철회 — 지원 chain 일괄 처리. 결과는 chain 별 [ChainTxResult] 목록.
  static Future<WalletResult<List<ChainTxResult>>> revoke(
      {required String address}) {
    return _guard(() async {
      final list = await NativeBridge.invokeList('revoke', {'address': address});
      return (list ?? const [])
          .map((e) => ChainTxResult.fromMap(e as Map))
          .toList();
    });
  }

  /// 결제 컨트랙트로의 토큰 approve(MAX) 셋업을 **지원 chain 전체**에 일괄 처리.
  ///
  /// 대상 chain × token 은 client 가 명시하지 않으며 WaaS 가 `project_assets` 의 활성 ERC-20 으로
  /// 자동 결정. 결과는 chain 별 [ChainTxResult] 목록 (성공/실패 모두 포함). delegate 선행 필요.
  static Future<WalletResult<List<ChainTxResult>>> approve(
      {required String address}) {
    return _guard(() async {
      final list = await NativeBridge.invokeList('approve', {'address': address});
      return (list ?? const [])
          .map((e) => ChainTxResult.fromMap(e as Map))
          .toList();
    });
  }

  /// 보류 중인 keyShare 를 OS 클라우드(iCloud / Block Store)에 백업.
  static Future<WalletResult<void>> backup() {
    return _guard(() async {
      await NativeBridge.invoke<void>('backup');
      return null;
    });
  }

  /// OS 클라우드 백업에서 지갑 복원. 지갑별 성공/실패 리스트 반환.
  static Future<WalletResult<List<RestoredKey>>> restore() {
    return _guard(() async {
      final list = await NativeBridge.invokeList('restore');
      return (list ?? const [])
          .map((e) => RestoredKey.fromMap(e as Map))
          .toList();
    });
  }

  /// (디버그) 백업 저장소 덤프.
  static Future<String> dumpBackupForDebug() async =>
      (await NativeBridge.invoke<String>('dumpBackupForDebug')) ?? '';

  /// (디버그) 모든 Tier 백업 데이터 삭제.
  static Future<void> clearBackupForDebug() async {
    await NativeBridge.invoke<void>('clearBackupForDebug');
  }

  /// (디버그/iOS) 저장된 App Attest 디바이스 키 삭제 → 다음 initialize 시 재attest.
  /// 백엔드에 미등록된 stale 키로 인증이 막힐 때 1회 호출. (Android 는 no-op)
  static Future<void> clearDeviceKeyForDebug() async {
    await NativeBridge.invoke<void>('clearDeviceKeyForDebug');
  }

  /// 공통 try/catch → WalletResult 래핑.
  static Future<WalletResult<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return WalletResult.success(await body());
    } on WalletError catch (e) {
      return WalletResult.failure(e);
    } catch (e) {
      return WalletResult.failure(WalletError.from(e));
    }
  }
}
