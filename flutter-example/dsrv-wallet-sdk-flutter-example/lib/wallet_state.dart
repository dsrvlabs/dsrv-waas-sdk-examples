import 'package:flutter/foundation.dart';
import 'package:dsrv_wallet_sdk/dsrv_wallet_sdk.dart';

import 'asset_value_repository.dart';
import 'config.dart';
import 'backend_auth_handler.dart';
import 'payment_repository.dart';
import 'token_config.dart';
import 'transaction_history_repository.dart';
import 'transfer_repository.dart';
import 'user_session.dart';

/// 앱 상태 + SDK 호출 — iOS `Wallet.swift` / Android `Wallet.kt` 와 1:1 대응.
class WalletState extends ChangeNotifier {
  // ===== Init / 식별자 =====

  bool initialized = false;
  bool initializing = false;
  String? initError;

  /// 사용자 입력 식별자. customer-backend `/sdk/registration` 의 `userCredential.value` 로
  /// 전달되는 [userUuid] 는 이 값을 시드로 결정적 생성 — 같은 userId 는 항상 같은 UUID.
  /// 앱 최초 진입 시 빈 문자열로 초기화되어 LoginScreen 에서 입력받는다.
  String userId = '';

  /// [userId] 시드로 만들어진 결정적 UUID (Login 화면에 미리 보여주는 값).
  String get userUuid => userId.isEmpty ? '' : userIdToUuid(userId);

  Future<void> loadUserIdFromStorage() async {
    userId = await loadUserId();
    notifyListeners();
  }

  /// userId 를 변경한다 (사용자 전환). 이미 SDK 초기화 상태라면 [DSRVWallet.reset] 으로
  /// `initialized` 플래그를 풀어 다음 [initialize] 가 새 [UserCredential] 로 진행되게 한다.
  Future<void> changeUserId(String newUserId) async {
    final trimmed = newUserId.trim();
    if (trimmed.isEmpty || trimmed == userId) return;

    if (initialized) {
      await DSRVWallet.reset();
      publicKey = '';
      address = '';
      initialized = false;
      initializing = false;
      initError = null;
      accounts = [];
      selectedAccountId = null;
      chains = [];
      selectedChainId = null;
      lastTxHash = null;
      transferError = null;
      historyItems = [];
      historyTotal = 0;
      historyPage = 0;
      historyError = null;
      delegateResults = [];
      revokeResults = [];
      approveResults = [];
      approveError = null;
      paymentResult = null;
      paymentError = null;
      backupResult = null;
      restoreResult = null;
      backupDump = null;
      _log('⚙ SDK reset (userId 변경)');
    }
    userId = trimmed;
    await saveUserId(trimmed);
    _log('⚙ userId="$trimmed" → uuid=${userUuid.substring(0, 12)}…');
    notifyListeners();
  }

  Future<void> resetWallet() async {
    if (initialized) {
      await DSRVWallet.reset();
    }
    publicKey = '';
    address = '';
    initialized = false;
    initializing = false;
    initError = null;
    accounts = [];
    selectedAccountId = null;
    chains = [];
    selectedChainId = null;
    lastTxHash = null;
    transferError = null;
    historyItems = [];
    historyTotal = 0;
    historyPage = 0;
    historyError = null;
    delegateResults = [];
    revokeResults = [];
    approveResults = [];
    approveError = null;
    paymentResult = null;
    paymentError = null;
    backupResult = null;
    restoreResult = null;
    backupDump = null;
    await clearUserId();
    userId = '';
    _log('▶ SDK reset — userId cleared');
    notifyListeners();
  }

  // ===== Wallet state =====

  List<AccountInfo> accounts = [];
  String? selectedAccountId;
  List<ChainInfo> chains = [];
  String? selectedChainId;

  String address = '';
  String publicKey = '';

  String? lastTxHash;
  String? transferError;
  List<TransactionHistoryItem> historyItems = [];
  int historyTotal = 0;
  int historyPage = 0;
  String? historyError;
  // chain 별 시도 결과 (성공/실패 모두 보존)
  List<ChainTxResult> delegateResults = [];
  List<ChainTxResult> revokeResults = [];
  List<ChainTxResult> approveResults = [];
  String? approveError;
  PaymentResponse? paymentResult;
  String? paymentError;
  String? backupResult;
  String? restoreResult;
  String? backupDump;

  final Set<String> _busy = {};
  bool busy(String tag) => _busy.contains(tag);

  final List<String> logs = [];

  void _log(String m) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    logs.insert(0, '[$t] $m');
    notifyListeners();
  }

  /// 외부 컴포넌트가 in-app Log 화면에 한 줄 남길 때 사용하는 public 진입점.
  void log(String m) => _log(m);

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  /// 공통 실행 래퍼: busy 토글 + 로그 + notify.
  Future<void> _op(String tag, Future<void> Function() body) async {
    _busy.add(tag);
    notifyListeners();
    try {
      await body();
    } catch (e) {
      _log('✗ $tag: $e');
    } finally {
      _busy.remove(tag);
      notifyListeners();
    }
  }

  // ===== SDK init =====

  Future<void> initialize() => _op('initialize', () async {
        if (userId.isEmpty) {
          initError = 'userId 를 먼저 입력하세요';
          return;
        }
        initializing = true;
        initError = null;
        _log('▶ initialize');
        _log('  userUuid=${userUuid.substring(0, 8)}…, sdkId=${AppConfig.sdkId}');
        _log('  customer-backend=${AppConfig.customerBackendUrl}');
        final r = await DSRVWallet.initialize(
          sdkId: AppConfig.sdkId,
          userCredential:
              UserCredential(type: CredentialType.userId, value: userUuid),
          authHandler: BackendAuthHandler(AppConfig.customerBackendUrl),
          baseUrl: AppConfig.dsrvApiBaseUrl,
        );
        initializing = false;
        r.fold((_) {
          initialized = true;
          _log('✓ initialize OK');
          // 초기화 직후 지원 chain 자동 조회
          getChainList();
        }, (e) {
          initError = e.message;
          _log('✗ initialize: ${e.message}');
        });
      });

  // ===== Account =====

  Future<void> createAccount(String label) => _op('createAccount', () async {
        if (!initialized) return;
        final lbl = label.isEmpty
            ? 'test-${DateTime.now().millisecondsSinceEpoch}'
            : label;
        _log('▶ createAccount(label=$lbl)');
        final r = await DSRVWallet.createAccount(label: lbl);
        r.fold((a) {
          selectedAccountId = a.accountId;
          _log('✓ accountId=${a.accountId}, label=${a.label}');
          getAccountList();
        }, (e) => _log('✗ ${e.message}'));
      });

  Future<void> getAccountList() => _op('getAccountList', () async {
        if (!initialized) return;
        _log('▶ getAccountList');
        final r = await DSRVWallet.getAccountList();
        r.fold((list) {
          accounts = list;
          // 기존 selectedAccountId 가 list 에 없으면 마지막 account 로 fallback
          final exists = list.any((a) => a.accountId == selectedAccountId);
          if (!exists) {
            selectedAccountId = list.isEmpty ? null : list.last.accountId;
          }
          _log('✓ accounts=${list.length} (selected=${selectedAccountId ?? "none"})');
        }, (e) => _log('✗ ${e.message}'));
      });

  void selectAccount(String accountId) {
    selectedAccountId = accountId;
    notifyListeners();
  }

  void selectWallet(String addr) {
    final normalized = addr.toLowerCase();
    final acc = accounts
        .expand((a) => a.addresses)
        .where((w) => w.address.toLowerCase() == normalized);
    address = acc.isEmpty ? normalized : acc.first.address.toLowerCase();
    publicKey = acc.isEmpty ? '' : acc.first.publicKey;
    notifyListeners();
  }

  // ===== Chain =====

  Future<void> getChainList() => _op('getChainList', () async {
        if (!initialized) return;
        _log('▶ getChainList');
        final r = await DSRVWallet.getChainList();
        r.fold((list) {
          chains = list;
          if (selectedChainId == null && list.isNotEmpty) {
            selectedChainId = list.first.chainId;
          }
          _log('✓ chains=${list.length}');
        }, (e) => _log('✗ ${e.message}'));
      });

  void selectChain(String chainId) {
    selectedChainId = chainId;
    notifyListeners();
  }

  /// 선택된 체인의 chainType (없으면 EVM 기본).
  String get selectedChainType {
    final m = chains.where((c) => c.chainId == selectedChainId);
    return m.isEmpty ? 'EVM' : m.first.chainType;
  }

  // ===== Create address =====

  Future<void> createAddress({String? label}) => _op('createAddress', () async {
        if (!initialized) return;
        final accountId = selectedAccountId;
        if (accountId == null || accountId.isEmpty) {
          _log('✗ accountId 가 필요합니다 (먼저 getAccountList / createAccount)');
          return;
        }
        final lbl = (label != null && label.isNotEmpty) ? label : null;
        final chainType = selectedChainType;
        _log('▶ createAddress(accountId=$accountId, chainType=$chainType, label=${lbl ?? "null"})');
        final r = await DSRVWallet.createAddress(
            accountId: accountId, chainType: chainType, label: lbl);
        r.fold((k) {
          address = k.address;
          publicKey = k.publicKey;
          _log('✓ address=${k.address}');
          getAccountList();
        }, (e) => _log('✗ ${e.message}'));
      });

  // ===== Transfer (customer-backend 경유 build + SDK sign + backend broadcast) =====

  late final TransferRepository _transferRepo =
      TransferRepository(AppConfig.customerBackendUrl);

  /// 전송 — 버튼 1회 = 3단계:
  ///   1) customer-backend `POST /sdk/transfer/build-hash`  → WaaS build, signId/messageHash/type
  ///   2) [DSRVWallet.sign] (디바이스 MPC sign — proxy 불가)
  ///   3) customer-backend `POST /sdk/transfer/broadcast`    → WaaS broadcast 후 txHash
  ///
  /// build/broadcast 는 customer-backend 가 자체 server-key 로 WaaS 호출 — example 은 user token 미전송.
  ///
  /// [contractAddress] 가 null 이면 native 전송, 있으면 ERC-20 전송.
  Future<void> transfer({
    required String chainId,
    required String recipient,
    required String amount,
    String? contractAddress,
  }) =>
      _op('transfer', () async {
        transferError = null;
        lastTxHash = null;
        if (!initialized) {
          transferError = 'SDK 가 초기화되지 않았습니다';
          notifyListeners();
          _log('✗ transfer: not initialized');
          return;
        }
        if (address.isEmpty) {
          transferError = 'address 가 없습니다 (createAddress 먼저)';
          notifyListeners();
          _log('✗ transfer: address empty');
          return;
        }
        if (recipient.isEmpty) {
          transferError = 'recipient 주소를 입력하세요';
          notifyListeners();
          _log('✗ transfer: recipient empty');
          return;
        }
        if (amount.isEmpty) {
          transferError = '금액을 입력하세요';
          notifyListeners();
          _log('✗ transfer: amount empty');
          return;
        }
        final c = chainId.isEmpty ? (selectedChainId ?? '') : chainId;
        if (c.isEmpty) {
          transferError = 'chain 을 먼저 선택하세요';
          notifyListeners();
          _log('✗ transfer: chainId empty');
          return;
        }
        final to = recipient;
        final amt = amount;

        transferError = null;
        _log('▶ transfer(chainId=$c, to=${to.substring(0, 10)}…, amount=$amount)');

        try {
          // ── 1) customer-backend build ─────────────────────────────
          _log('  [1/3] backend build-hash');
          final build = await _transferRepo.buildHash(BuildTransferRequest(
            fromAddress: address,
            toAddress: to,
            amount: amount,
            chainId: c,
            contractAddress: contractAddress,
          ));
          _log('       type=${build.type}, txId=${build.txId.substring(0, build.txId.length > 20 ? 20 : build.txId.length)}…');

          // ── 2) SDK sign (디바이스 MPC) ─────────────────────────────
          _log('  [2/3] SDK MPC sign');
          final signRes = await DSRVWallet.sign(
            address: address,
            hashedMessage: build.messageHash,
            signId: build.signId,
            messageType: build.type,
          );
          final signFailed = signRes.fold(
            (_) => null,
            (e) => e.message,
          );
          if (signFailed != null) {
            transferError = 'MPC sign 실패: $signFailed';
            notifyListeners();
            _log('✗ transfer sign FAILED: $signFailed');
            return;
          }
          _log('       sign OK');

          // ── 3) customer-backend broadcast ─────────────────────────
          _log('  [3/3] backend broadcast');
          final broadcast = await _transferRepo
              .broadcast(BroadcastTransferRequest(txId: build.txId));
          lastTxHash = broadcast.txHash;
          if (broadcast.txHash != null) {
            _log('✓ transfer txHash=${broadcast.txHash} (status=${broadcast.status})');
          } else {
            _log('✓ transfer queued — status=${broadcast.status}, batchTxId=${broadcast.batchTxId} (bundler 경로, txHash 후속 polling)');
          }
        } catch (e) {
          transferError = '전송 실패: $e';
          notifyListeners();
          _log('✗ transfer FAILED: $e');
        }
      });

  // ===== Transaction history (customer-backend GET /sdk/transactions) =====

  late final TransactionHistoryRepository _historyRepo =
      TransactionHistoryRepository(AppConfig.customerBackendUrl);

  /// 거래 내역 조회 — 선택된 지갑 [address] 기준 (fromAddress 필터).
  ///
  /// customer-backend `GET /sdk/transactions` 호출 → WaaS
  /// `GET /api/v1/embedded-wallets/ncw/transactions?searchBy=FROM_ADDRESS` 프록시.
  /// build/broadcast 와 마찬가지로 customer-backend 가 자체 server-key 로 WaaS 호출.
  ///
  /// [loadMore] true 면 다음 페이지를 기존 목록 뒤에 append, false 면 1페이지부터 새로 조회.
  Future<void> getTransactionHistory({bool loadMore = false}) =>
      _op('history', () async {
        if (!initialized) {
          historyError = 'SDK가 초기화되지 않았습니다';
          return;
        }
        if (address.isEmpty) {
          historyError = 'address 가 필요합니다';
          return;
        }
        final page = loadMore ? historyPage + 1 : 1;

        historyError = null;
        _log('▶ getTransactionHistory(address=${address.substring(0, 10)}…, page=$page)');
        try {
          final response = await _historyRepo.getTransactions(
            address: address,
            page: page,
          );
          historyItems =
              loadMore ? [...historyItems, ...response.items] : response.items;
          historyTotal = response.pagination.total;
          historyPage = response.pagination.page;
          _log('✓ getTransactionHistory page=${response.pagination.page}, count=${response.items.length}, total=${response.pagination.total}');
        } catch (e) {
          historyError = '$e';
          _log('✗ getTransactionHistory FAILED: $e');
        }
      });

  // ===== Asset value (KRW 환산) =====

  late final AssetValueRepository _assetValueRepo =
      AssetValueRepository(AppConfig.customerBackendUrl);

  /// 보유분 KRW 환산값 — 포맷된 "₩..." 문자열, 시세 미가용/실패 시 null.
  /// 잔액 RPC 조회는 View 가, 가치 조회+포맷은 여기서 담당한다 (Android `Wallet.getKrwValue` 와 동일).
  /// 자체 try/catch 로 실패를 흡수하므로 호출 측 잔액 표시 흐름과 독립적이다.
  Future<String?> getKrwValue({
    required String chainId,
    String? contractAddress,
    required String amount,
  }) async {
    final label =
        (contractAddress != null && contractAddress.isNotEmpty) ? contractAddress : 'NATIVE';
    try {
      // 잔액 0 → 0개 × 단가 = ₩0. 백엔드는 amount=0 이면 holdings 를 생략하므로 직접 표시.
      if (amount.replaceAll(RegExp(r'[.0]'), '').isEmpty) {
        return _formatKrw('0');
      }
      final res = await _assetValueRepo.getLatestValue(
        chainId: chainId,
        contractAddress: contractAddress,
        amount: amount,
      );
      final total = res.holdings?.totalValue;
      if (total == null) {
        _log('⚠ KRW 시세 미가용: chainId=$chainId contract=$label');
        return null;
      }
      return _formatKrw(total);
    } catch (e) {
      _log('✗ KRW 환산 실패: chainId=$chainId contract=$label — $e');
      return null;
    }
  }

  /// 지수표기("1e-7", "1.23E+21")를 평문 10진수 문자열로 펼친다.
  /// AssetValueRepository 가 JSON number 를 `num.toString()` 으로 정규화할 때 매우 크거나 작은 값은
  /// 지수표기가 나올 수 있어, [_formatKrw] 의 BigInt.parse 가 깨지는 것을 방지한다. 평문이면 그대로 반환.
  String _toPlainDecimal(String s) {
    final lower = s.toLowerCase();
    final eIdx = lower.indexOf('e');
    if (eIdx < 0) return s;
    final neg = s.startsWith('-');
    final mantissa = neg ? s.substring(1, eIdx) : s.substring(0, eIdx);
    final exp = int.tryParse(s.substring(eIdx + 1)) ?? 0;
    final dot = mantissa.indexOf('.');
    final digits = dot < 0 ? mantissa : mantissa.replaceFirst('.', '');
    final pointPos = (dot < 0 ? mantissa.length : dot) + exp;
    String result;
    if (pointPos <= 0) {
      result = '0.${'0' * (-pointPos)}$digits';
    } else if (pointPos >= digits.length) {
      result = digits + '0' * (pointPos - digits.length);
    } else {
      result = '${digits.substring(0, pointPos)}.${digits.substring(pointPos)}';
    }
    return neg ? '-$result' : result;
  }

  /// totalValue ("345690.4521") → "₩345,690.45" — 천 단위 구분 + 소수점 2자리 반올림.
  ///
  /// price-hub 의 BigDecimal 직렬화값이므로 double 변환 없이 문자열/BigInt 로 처리해
  /// 큰 값/긴 소수에서의 정밀도 손실을 피한다 (round-half-up).
  String _formatKrw(String rawValue) {
    final totalValue = _toPlainDecimal(rawValue.trim());
    final neg = totalValue.startsWith('-');
    final unsigned = neg ? totalValue.substring(1) : totalValue;
    final dot = unsigned.indexOf('.');
    final intPart = dot < 0 ? unsigned : unsigned.substring(0, dot);
    final fracPart = dot < 0 ? '' : unsigned.substring(dot + 1);
    // 정수부 + 소수 2자리를 합쳐 정수(cents)로 만든 뒤 3번째 소수 자리로 반올림.
    final frac2 = fracPart.padRight(3, '0');
    var cents =
        BigInt.parse((intPart.isEmpty ? '0' : intPart) + frac2.substring(0, 2));
    if (int.parse(frac2[2]) >= 5) cents += BigInt.one;
    final centsStr = cents.toString().padLeft(3, '0');
    final whole = centsStr.substring(0, centsStr.length - 2);
    final cent = centsStr.substring(centsStr.length - 2);
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '${neg ? '-' : ''}₩$grouped.$cent';
  }

  // ===== Delegate / Revoke (EIP-7702) =====

  Future<void> delegate() => _op('delegate', () async {
        if (!initialized || address.isEmpty) return;
        _log('▶ delegate(address=$address)');
        final r = await DSRVWallet.delegate(address: address);
        r.fold((list) {
          delegateResults = list;
          _logChainResults('delegate', list);
        }, (e) => _log('✗ ${e.message}'));
      });

  Future<void> revoke() => _op('revoke', () async {
        if (!initialized || address.isEmpty) return;
        _log('▶ revoke(address=$address)');
        final r = await DSRVWallet.revoke(address: address);
        r.fold((list) {
          revokeResults = list;
          delegateResults = [];
          _logChainResults('revoke', list);
        }, (e) => _log('✗ ${e.message}'));
      });

  // ===== Approve (multicall — 지원 chain 전체 일괄, delegate 선행 필요) =====

  /// 결제 컨트랙트로의 토큰 approve 셋업을 **지원 chain 전체**에 일괄 처리한다.
  /// 대상 token 은 WaaS 의 `project_assets` 에 등록된 활성 ERC-20 으로 자동 결정 (client 입력 없음).
  /// 결과는 chain 별 [ChainTxResult] 목록 — 성공/실패 모두 보존.
  ///
  /// [amount]: "MAX" (unbounded) 또는 "0" (revoke). 비어 있으면 "MAX". SDK 가 uppercase 정규화.
  Future<void> approve({String amount = ''}) => _op('approve', () async {
        if (!initialized || address.isEmpty) {
          approveError = 'address 가 필요합니다 (createAddress 먼저 실행)';
          return;
        }
        final resolvedAmount = amount.isEmpty ? 'MAX' : amount;
        approveResults = [];
        approveError = null;
        _log('▶ approve(address=${address.substring(0, 10)}…, amount=$resolvedAmount)');
        final r = await DSRVWallet.approve(address: address, amount: resolvedAmount);
        r.fold((list) {
          approveResults = list;
          _logChainResults('approve', list);
        }, (e) {
          approveError = e.message;
          _log('✗ approve: ${e.message}');
        });
      });

  /// chain 별 결과 summary + 각 chain 의 outcome 을 한 줄씩 로그에 출력.
  void _logChainResults(String tag, List<ChainTxResult> list) {
    if (list.isEmpty) {
      _log('ⓘ $tag: 처리할 chain 없음');
      return;
    }
    final successes = list.where((r) => r.isSuccess).length;
    final failures = list.length - successes;
    _log('✓ $tag (success=$successes / failed=$failures of ${list.length})');
    for (final item in list) {
      if (!item.isSuccess) {
        _log('  ✗ ${item.chainId} [${item.outcome}]: ${item.errorMessage ?? "unknown"}');
      } else if (item.txHash != null) {
        _log('  ✓ ${item.chainId} [${item.outcome}]: ${item.txHash}');
      } else {
        _log('  ✓ ${item.chainId} [${item.outcome}]');  // ALREADY_DELEGATED / SKIPPED
      }
    }
  }

  // ===== Payment (customer-backend POST /payments — TOPUP) =====

  late final PaymentRepository _paymentRepo =
      PaymentRepository(AppConfig.customerBackendUrl);

  /// customer-backend `POST /payments` 호출. 서버가 quote → paymentDigest 서명 → execute 통합.
  ///
  /// 비어 있는 입력은 default 채움: sourceUserId=userUuid (raw userId 시드의 결정적 UUID —
  /// WaaS 가 topup wallet 등록 시 external_user_ref 로 박는 값과 일치), chainId=selectedChainId,
  /// token=USDC, from=address, paymentType=0
  Future<void> pay({
    String chainId = '',
    String token = '',
    required String to,
    required String amount,
  }) =>
      _op('pay', () async {
        if (!initialized || address.isEmpty) {
          paymentError = 'address 가 필요합니다 (create 먼저 실행)';
          return;
        }
        if (to.isEmpty) {
          paymentError = 'to 주소를 입력하세요 (SETTLEMENT 지갑)';
          return;
        }
        if (amount.isEmpty) {
          paymentError = 'amount (예: 1.5) 를 입력하세요';
          return;
        }

        final c = chainId.isEmpty ? (selectedChainId ?? '') : chainId;
        if (c.isEmpty) {
          paymentError = 'chain 을 먼저 선택하세요';
          return;
        }
        final chainIdInt = int.tryParse(c);
        if (chainIdInt == null) {
          paymentError = 'chainId 정수 변환 실패: $c';
          return;
        }
        final String resolvedToken;
        if (token.isEmpty) {
          final usdc = TokenConfig.getToken(c, 'USDC');
          if (usdc == null) {
            paymentError = 'chainId=$c 의 USDC 주소가 정의되지 않았습니다. token 직접 입력';
            return;
          }
          resolvedToken = usdc.address;
        } else {
          resolvedToken = token;
        }

        paymentResult = null;
        paymentError = null;
        _log('▶ pay(chainId=$chainIdInt, from=${address.substring(0, 10)}…, to=${to.substring(0, 10)}…, amount=$amount)');
        try {
          paymentResult = await _paymentRepo.pay(PaymentRequest(
            // raw userId 가 아닌 userUuid (UUID v3 derive) — wallet_topup.external_user_ref 와 일치.
            sourceUserId: userUuid,
            chainId: chainIdInt,
            token: resolvedToken,
            from: address,
            to: to.trim(),
            amount: amount.trim(),
            paymentType: 0,
          ));
          _log('✓ pay status=${paymentResult!.status}, txHash=${paymentResult!.txHash ?? "(pending)"}, paymentUuid=${paymentResult!.paymentUuid}');
        } catch (e) {
          paymentError = '$e';
          _log('✗ pay FAILED: $e');
        }
      });

  // ===== Backup / Restore =====

  Future<void> backup() => _op('backup', () async {
        if (!initialized) return;
        backupResult = null;
        _log('▶ backup');
        final r = await DSRVWallet.backup();
        r.fold((_) {
          backupResult = '백업 완료';
          _log('✓ backup OK');
        }, (e) => _log('✗ ${e.message}'));
      });

  Future<void> restore() => _op('restore', () async {
        if (!initialized) return;
        restoreResult = null;
        _log('▶ restore');
        final r = await DSRVWallet.restore();
        r.fold((list) {
          final ok = list.where((e) => e.success).length;
          final fail = list.length - ok;
          restoreResult = '복원: 성공 $ok / 실패 $fail';
          _log('✓ $restoreResult');
          // 복원 후 계정 목록 새로고침
          getAccountList();
        }, (e) => _log('✗ ${e.message}'));
      });

  // ===== Debug =====

  Future<void> dumpBackup() => _op('dump', () async {
        _log('▶ dumpBackupForDebug');
        backupDump = await DSRVWallet.dumpBackupForDebug();
        _log('✓ dump (${backupDump?.length ?? 0}B)');
      });

  Future<void> clearBackup() => _op('clearBackup', () async {
        _log('▶ clearBackupForDebug');
        await DSRVWallet.clearBackupForDebug();
        backupDump = await DSRVWallet.dumpBackupForDebug();
        _log('✓ backup 전체 삭제');
      });

  Future<void> clearDeviceKey() => _op('clearDeviceKey', () async {
        _log('▶ clearDeviceKeyForDebug');
        await DSRVWallet.clearDeviceKeyForDebug();
        _log('✓ device key 삭제 — 이제 Initialize 다시');
      });
}
