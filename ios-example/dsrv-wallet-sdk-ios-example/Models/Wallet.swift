import SwiftUI
import Foundation
import Combine
import CommonCrypto
import dsrv_wallet_sdk_ios

public enum Config {
    public static let customerBackendURL = "https://your-backend.com"
    public static let sdkId = "your-sdk-id"
    /// nil 이면 SDK 기본값 사용
    public static let dsrvApiBaseUrl: String = "https://api.dsrv.com"
}

struct WalletUiState {
    var sdkInitialized: Bool = false
    var sdkInitializing: Bool = false
    var sdkInitError: String? = nil

    // Account
    var createAccountLoading: Bool = false
    var createAccountError: String? = nil
    var accountsLoading: Bool = false
    var accountsError: String? = nil
    var accounts: [AccountInfo] = []
    var selectedAccountId: String? = nil

    // Chain
    var chainsLoading: Bool = false
    var chainsError: String? = nil
    var chains: [ChainInfo] = []
    var selectedChainId: String? = nil

    // Create
    var createLoading: Bool = false
    var createError: String? = nil

    // Transfer (원샷: buildTx + sign + broadcastTx)
    var transferLoading: Bool = false
    var transferError: String? = nil
    var lastTxHash: String? = nil

    // Backup
    var backupLoading: Bool = false
    var backupError: String? = nil
    var backupResult: String? = nil
    var keychainDump: String? = nil

    // Restore
    var restoreLoading: Bool = false
    var restoreError: String? = nil
    var restoreResult: String? = nil

    // Delegate / Revoke — chain 별 시도 결과 (성공/실패 모두 보존)
    var delegateLoading: Bool = false
    var delegateError: String? = nil
    var delegateResults: [ChainTxResult] = []
    var delegateAlreadyDone: Bool = false

    // Approve — chain 별 시도 결과
    var approveLoading: Bool = false
    var approveError: String? = nil
    var approveResults: [ChainTxResult] = []

    // Payment (customer-backend POST /payments — TOPUP)
    var paymentLoading: Bool = false
    var paymentError: String? = nil
    var paymentResult: PaymentResponse? = nil

    // Transaction history (customer-backend GET /sdk/transactions)
    var historyLoading: Bool = false
    var historyError: String? = nil
    var historyItems: [TransactionHistoryItem] = []
    var historyTotal: Int = 0
    var historyPage: Int = 0

    // Logs
    var logs: [String] = []
}

@MainActor
final class Wallet: ObservableObject {

    private static let keyUserId = "user_id"
    private let prefs = UserDefaults.standard

    // demo 용 fallback — selectedChainId 가 없을 때만 사용 (Sepolia)
    private let demoChainIdFallback = "11155111"

    @Published var uiState = WalletUiState()
    /// 선택된 지갑의 EVM address (0x-prefixed). SDK API 호출의 주 식별자.
    @Published var address: String = ""
    /// 선택된 지갑의 publicKey (UI 표시 용도).
    @Published var publicKey: String = ""

    /// 사용자 입력 식별자. 같은 userId 는 항상 같은 [userUuid] 를 만들어낸다.
    /// 앱 최초 진입 시 빈 문자열로 초기화되어 LoginScreen 에서 입력받는다.
    @Published private(set) var userId: String = ""

    let sdkId = Config.sdkId
    let customerBackendUrl = Config.customerBackendURL

    private var authHandler: MyAuthHandler?

    init() {
        userId = prefs.string(forKey: Self.keyUserId) ?? ""
    }

    /// userId 시드로 만들어진 결정적 UUID (Login 화면에 미리 보여주는 값).
    var userUuid: String {
        userId.isEmpty ? "" : Self.userIdToUuid(userId)
    }

    // MARK: - userId

    /// userId 를 MD5 시드로 결정적 UUID v3 형식을 생성한다. Java 의 `UUID.nameUUIDFromBytes` 와
    /// 동일한 결과를 만들어 cross-platform 일관 매핑을 보장한다.
    static func userIdToUuid(_ userId: String) -> String {
        let seed = "dsrv-wallet-example:\(userId.trimmingCharacters(in: .whitespaces))"
        let bytes = Array(seed.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        bytes.withUnsafeBufferPointer { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(bytes.count), &digest)
        }
        // v3: set version 0011 in byte 6, variant 10 in byte 8
        digest[6] = (digest[6] & 0x0F) | 0x30
        digest[8] = (digest[8] & 0x3F) | 0x80
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let s = hex
        let idx = { (i: Int) in s.index(s.startIndex, offsetBy: i) }
        return [
            String(s[idx(0)..<idx(8)]),
            String(s[idx(8)..<idx(12)]),
            String(s[idx(12)..<idx(16)]),
            String(s[idx(16)..<idx(20)]),
            String(s[idx(20)..<idx(32)]),
        ].joined(separator: "-")
    }

    /// userId 를 변경한다 (사용자 전환). SDK reset → 다음 retryInitialize() 에서
    /// 새 userCredential 로 재인증된다.
    func changeUserId(_ newUserId: String) {
        let trimmed = newUserId.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == userId { return }

        if uiState.sdkInitialized {
            Task { await DSRVWallet.reset() }
            publicKey = ""
            address = ""
            uiState = WalletUiState()
            addLog("⚙ SDK reset (userId 변경)")
        }

        userId = trimmed
        prefs.set(trimmed, forKey: Self.keyUserId)
        addLog("⚙ userId='\(trimmed)' → uuid=\(userUuid.prefix(12))…")
    }

    func resetWallet() {
        if uiState.sdkInitialized {
            Task { await DSRVWallet.reset() }
        }
        publicKey = ""
        address = ""
        prefs.removeObject(forKey: Self.keyUserId)
        uiState = WalletUiState()
        userId = ""
        addLog("▶ SDK reset — userId cleared")
    }

    // MARK: - Logging

    private func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)"
        print(line)
        uiState.logs.append(line)
    }

    func clearLogs() {
        uiState.logs = []
    }

    // MARK: - Init

    private func initializeSdk() async {
        addLog("▶ initialize")
        uiState.sdkInitializing = true
        uiState.sdkInitError = nil

        let handler = MyAuthHandler(backendUrl: customerBackendUrl)
        self.authHandler = handler
        let userCredential = UserCredential(type: .userId, value: userUuid, provider: "")
        addLog("  userUuid=\(userUuid.prefix(8))…, sdkId=\(sdkId)")
        addLog("  customer-backend=\(customerBackendUrl)")

        let result = await DSRVWallet.initialize(
            sdkId: sdkId,
            userCredential: userCredential,
            authHandler: handler,
            baseUrl: Config.dsrvApiBaseUrl
        )

        switch result {
        case .success:
            uiState.sdkInitialized = true
            uiState.sdkInitializing = false
            uiState.sdkInitError = nil
            addLog("✓ initialize OK")
            getChainList()
        case .failure(let error):
            uiState.sdkInitialized = false
            uiState.sdkInitializing = false
            uiState.sdkInitError = error.description
            addLog("✗ initialize FAILED: \(error.description)")
        }
    }

    func retryInitialize() {
        guard !uiState.sdkInitializing else { return }
        if userId.isEmpty {
            uiState.sdkInitError = "userId 를 먼저 입력하세요"
            return
        }
        uiState.sdkInitializing = true
        uiState.sdkInitError = nil
        Task { await initializeSdk() }
    }

    // MARK: - Account

    func createAccount(label labelInput: String = "") {
        guard uiState.sdkInitialized else { return }
        let label = labelInput.trimmingCharacters(in: .whitespaces).isEmpty
            ? "test-\(Int(Date().timeIntervalSince1970 * 1000))"
            : labelInput
        uiState.createAccountLoading = true
        uiState.createAccountError = nil
        addLog("▶ createAccount(label=\(label))")

        Task {
            let result = await DSRVWallet.createAccount(label: label)
            uiState.createAccountLoading = false
            switch result {
            case .success(let r):
                uiState.selectedAccountId = r.accountId
                addLog("✓ createAccount accountId=\(r.accountId), label=\(r.label)")
                getAccountList()
            case .failure(let error):
                uiState.createAccountError = error.description
                addLog("✗ createAccount FAILED: \(error.description)")
            }
        }
    }

    func getAccountList() {
        guard uiState.sdkInitialized else { return }
        uiState.accountsLoading = true
        uiState.accountsError = nil
        addLog("▶ getAccountList")

        Task {
            let result = await DSRVWallet.getAccountList()
            uiState.accountsLoading = false
            switch result {
            case .success(let list):
                let prev = uiState.selectedAccountId
                let stillValid = prev.flatMap { p in list.first { $0.accountId == p }?.accountId }
                let selected = stillValid ?? list.last?.accountId
                uiState.accounts = list
                uiState.selectedAccountId = selected
                addLog("✓ getAccountList count=\(list.count) (selected=\(selected ?? "none"))")
                for acc in list {
                    addLog("  accountId=\(acc.accountId), label=\(acc.label), addresses=\(acc.addresses.count)")
                }
            case .failure(let error):
                uiState.accountsError = error.description
                addLog("✗ getAccountList FAILED: \(error.description)")
            }
        }
    }

    /// 사용자가 계정 목록 중에서 명시적으로 선택할 때.
    func selectAccount(_ accountId: String) {
        guard let acc = uiState.accounts.first(where: { $0.accountId == accountId }) else { return }
        let first = acc.addresses.first
        address = first?.address.lowercased() ?? ""
        publicKey = first?.publicKey ?? ""
        uiState.selectedAccountId = accountId
        addLog("⚙ account selected: \(acc.label) (\(acc.accountId.prefix(8))…), wallet=\(address.isEmpty ? "(none)" : address)")
    }

    /// 같은 계정 안에 여러 address 가 있을 때 선택.
    func selectWallet(_ addr: String) {
        let normalized = addr.lowercased()
        let info = uiState.accounts
            .flatMap { $0.addresses }
            .first { $0.address.lowercased() == normalized }
        address = info?.address.lowercased() ?? normalized
        publicKey = info?.publicKey ?? ""
        addLog("⚙ wallet selected: \(address.prefix(20))…")
    }

    // MARK: - Chain

    func getChainList() {
        guard uiState.sdkInitialized else { return }
        uiState.chainsLoading = true
        uiState.chainsError = nil
        addLog("▶ getChainList")

        Task {
            let result = await DSRVWallet.getChainList()
            uiState.chainsLoading = false
            switch result {
            case .success(let list):
                let selected = uiState.selectedChainId ?? list.first?.chainId
                uiState.chains = list
                uiState.selectedChainId = selected
                addLog("✓ getChainList count=\(list.count)")
                for c in list {
                    addLog("  chainId=\(c.chainId), name=\(c.name), type=\(c.chainType)/\(c.networkType)")
                }
            case .failure(let error):
                uiState.chainsError = error.description
                addLog("✗ getChainList FAILED: \(error.description)")
            }
        }
    }

    func selectChain(_ chainId: String) {
        uiState.selectedChainId = chainId
        addLog("⚙ selected chainId=\(chainId)")
    }

    // MARK: - Create

    func createAddress(accountIdInput: String = "", labelInput: String = "") {
        guard uiState.sdkInitialized else {
            uiState.createError = "SDK가 초기화되지 않았습니다"
            return
        }
        // 입력값 우선, 없으면 메모리에 보관된 selectedAccountId. accountId 는 SDK 필수.
        let accountId: String? = accountIdInput.isEmpty ? uiState.selectedAccountId : accountIdInput
        guard let accountId, !accountId.isEmpty else {
            uiState.createError = "accountId 가 필요합니다 (먼저 getAccountList / createAccount)"
            return
        }
        let label: String? = labelInput.isEmpty ? nil : labelInput
        let chainType = uiState.chains
            .first(where: { $0.chainId == uiState.selectedChainId })?.chainType ?? "EVM"

        uiState.createLoading = true
        uiState.createError = nil
        addLog("▶ createAddress(accountId=\(accountId), chainType=\(chainType), label=\(label ?? "null"))")

        Task {
            let result = await DSRVWallet.createAddress(accountId: accountId, chainType: chainType, label: label)
            uiState.createLoading = false
            switch result {
            case .success(let created):
                publicKey = created.publicKey
                address = created.address
                uiState.createError = nil
                addLog("✓ createAddress address=\(created.address), publicKey=\(created.publicKey.prefix(20))…")
                getAccountList()
            case .failure(let error):
                uiState.createError = error.description
                addLog("✗ create FAILED: \(error.description)")
            }
        }
    }

    // MARK: - Transfer

    /// 전송 — 헤더 선택 체인 + 선택 지갑 사용. amount 는 사람이 읽는 단위 ("0.001", "1.5").
    ///
    /// 흐름 (버튼 1회 = 3단계):
    ///   1) customer-backend `POST /sdk/transfer/build-hash`  → WaaS build, signId/messageHash/type 반환
    ///   2) `DSRVWallet.sign` (디바이스 MPC sign — 디바이스 ↔ MPC 서버 직통, proxy 불가)
    ///   3) customer-backend `POST /sdk/transfer/broadcast`    → WaaS broadcast 후 txHash 반환
    ///
    /// build/broadcast 는 customer-backend 가 자체 server-key 로 WaaS 호출 — example 은 user token 미전송.
    ///
    /// @param tokenSymbol "ETH" (native) 또는 TokenConfig 에 정의된 ERC-20 심볼 (예: "USDC")
    func transfer(recipientInput: String, amountInput: String, tokenSymbol: String = "ETH") {
        guard uiState.sdkInitialized else {
            uiState.transferError = "SDK가 초기화되지 않았습니다"
            return
        }
        let addr = address
        if addr.isEmpty {
            uiState.transferError = "address 가 필요합니다"
            return
        }
        let chainId = uiState.selectedChainId ?? demoChainIdFallback
        if recipientInput.trimmingCharacters(in: .whitespaces).isEmpty {
            uiState.transferError = "수신 주소를 입력하세요"
            return
        }
        let recipient = recipientInput

        let contractAddress: String?
        let decimals: Int
        let defaultHuman: String
        if tokenSymbol == "ETH" {
            contractAddress = nil
            decimals = 18
            defaultHuman = "0.001"
        } else {
            guard let token = TokenConfig.getToken(chainId: chainId, symbol: tokenSymbol) else {
                uiState.transferError = "chainId=\(chainId) 에 정의된 \(tokenSymbol) 이 없습니다 (설정에서 추가)"
                return
            }
            contractAddress = token.address
            decimals = token.decimals
            defaultHuman = "1"
        }
        let humanAmount = amountInput.trimmingCharacters(in: .whitespaces).isEmpty ? defaultHuman : amountInput
        let amount: String
        do {
            amount = try toBaseUnits(humanAmount, decimals: decimals)
        } catch {
            uiState.transferError = "amount 형식 오류: \(error.localizedDescription)"
            return
        }

        uiState.transferLoading = true
        uiState.transferError = nil
        addLog("▶ transfer(\(tokenSymbol), chainId=\(chainId), to=\(recipient.prefix(10))…, amount=\(humanAmount) → \(amount) base)")

        let repo = TransferRepository(backendUrl: customerBackendUrl)

        Task {
            do {
                // ── 1) customer-backend build ─────────────────────────
                addLog("  [1/3] backend build-hash")
                let build = try await repo.buildHash(
                    BuildTransferRequest(
                        fromAddress: addr,
                        toAddress: recipient,
                        amount: amount,
                        chainId: chainId,
                        contractAddress: contractAddress
                    )
                )
                addLog("       type=\(build.type), txId=\(build.txId.prefix(20))…")

                // ── 2) SDK sign (디바이스 MPC) ─────────────────────────
                addLog("  [2/3] SDK MPC sign")
                let signResult = await DSRVWallet.sign(
                    address: addr,
                    hashedMessage: build.messageHash,
                    signId: build.signId,
                    messageType: build.type
                )
                switch signResult {
                case .failure(let err):
                    uiState.transferLoading = false
                    uiState.transferError = err.description
                    addLog("✗ transfer sign FAILED: \(err.description)")
                    return
                case .success:
                    addLog("       sign OK")
                }

                // ── 3) customer-backend broadcast ─────────────────────
                addLog("  [3/3] backend broadcast")
                let broadcast = try await repo.broadcast(
                    BroadcastTransferRequest(txId: build.txId)
                )
                uiState.transferLoading = false
                uiState.lastTxHash = broadcast.txHash
                if let hash = broadcast.txHash {
                    addLog("✓ transfer txHash=\(hash) (status=\(broadcast.status))")
                } else {
                    addLog("✓ transfer queued — status=\(broadcast.status), batchTxId=\(broadcast.batchTxId) (bundler 경로, txHash 후속 polling)")
                }
            } catch {
                uiState.transferLoading = false
                uiState.transferError = "\(error)"
                addLog("✗ transfer FAILED: \(error)")
            }
        }
    }

    // MARK: - Transaction history (customer-backend GET /sdk/transactions)

    /// 거래 내역 조회 — 선택된 지갑 `address` 기준 (fromAddress 필터).
    ///
    /// customer-backend `GET /sdk/transactions` 호출 → WaaS
    /// `GET /api/v1/embedded-wallets/ncw/transactions?searchBy=FROM_ADDRESS` 프록시.
    /// build/broadcast 와 마찬가지로 customer-backend 가 자체 server-key 로 WaaS 호출.
    ///
    /// - Parameter loadMore: true 면 다음 페이지를 기존 목록 뒤에 append, false 면 1페이지부터 새로 조회
    func getTransactionHistory(loadMore: Bool = false) {
        guard uiState.sdkInitialized else {
            uiState.historyError = "SDK가 초기화되지 않았습니다"
            return
        }
        let addr = address
        if addr.isEmpty {
            uiState.historyError = "address 가 필요합니다"
            return
        }
        if uiState.historyLoading { return }
        let page = loadMore ? uiState.historyPage + 1 : 1

        uiState.historyLoading = true
        uiState.historyError = nil
        addLog("▶ getTransactionHistory(address=\(addr.prefix(10))…, page=\(page))")

        let repo = TransactionHistoryRepository(backendUrl: customerBackendUrl)

        Task {
            do {
                let response = try await repo.getTransactions(
                    address: addr,
                    page: page
                )
                uiState.historyLoading = false
                uiState.historyItems = loadMore ? uiState.historyItems + response.items : response.items
                uiState.historyTotal = response.pagination.total
                uiState.historyPage = response.pagination.page
                addLog("✓ getTransactionHistory page=\(response.pagination.page), count=\(response.items.count), total=\(response.pagination.total)")
            } catch {
                uiState.historyLoading = false
                uiState.historyError = "\(error)"
                addLog("✗ getTransactionHistory FAILED: \(error)")
            }
        }
    }

    // MARK: - Backup / Restore

    func dumpKeychain() {
        guard uiState.sdkInitialized else { return }
        addLog("▶ dumpKeychain()")
        let dump = DSRVWallet.dumpBackupForDebug()
        uiState.keychainDump = dump
        addLog("✓ dumpKeychain (\(dump.count)B)")
    }

    func clearBackup() {
        guard uiState.sdkInitialized else { return }
        addLog("▶ clearBackupForDebug()")
        DSRVWallet.clearBackupForDebug()
        uiState.keychainDump = DSRVWallet.dumpBackupForDebug()
        addLog("✓ backup 전체 삭제 완료")
    }

    func backup() {
        guard uiState.sdkInitialized else {
            uiState.backupError = "SDK 가 초기화되지 않았습니다"
            return
        }
        uiState.backupLoading = true
        uiState.backupError = nil
        uiState.backupResult = nil
        addLog("▶ backup()")

        Task {
            let result = await DSRVWallet.backup()
            uiState.backupLoading = false
            switch result {
            case .success:
                uiState.backupResult = "백업 완료"
                addLog("✓ backup OK")
            case .failure(let error):
                uiState.backupError = error.description
                addLog("✗ backup FAILED: \(error.description)")
            }
        }
    }

    // MARK: - Delegate / Revoke (EIP-7702)

    func delegate(addressInput: String = "") {
        guard uiState.sdkInitialized else {
            uiState.delegateError = "SDK 가 초기화되지 않았습니다"
            return
        }
        let addr = addressInput.isEmpty ? address : addressInput
        if addr.isEmpty {
            uiState.delegateError = "address 가 필요합니다 (create 먼저 실행)"
            return
        }
        uiState.delegateLoading = true
        uiState.delegateError = nil
        uiState.delegateResults = []
        uiState.delegateAlreadyDone = false
        addLog("▶ delegate(address=\(addr))")

        Task {
            let result = await DSRVWallet.delegate(address: addr)
            uiState.delegateLoading = false
            switch result {
            case .success(let list):
                let successes = list.filter { $0.isSuccess }.count
                let failures = list.count - successes
                uiState.delegateResults = list
                uiState.delegateAlreadyDone = list.isEmpty
                if list.isEmpty {
                    addLog("ⓘ delegate skip: 이미 위임됨")
                } else {
                    addLog("✓ delegate (success=\(successes) / failed=\(failures) of \(list.count))")
                    for item in list {
                        if !item.isSuccess {
                            addLog("  ✗ \(item.chainId) [\(item.outcome)]: \(item.errorMessage ?? "unknown")")
                        } else if let h = item.txHash {
                            addLog("  ✓ \(item.chainId) [\(item.outcome)]: \(h)")
                        } else {
                            // ALREADY_DELEGATED / SKIPPED — txHash 없음
                            addLog("  ✓ \(item.chainId) [\(item.outcome)]")
                        }
                    }
                }
            case .failure(let error):
                let msg = error.description
                if msg.contains("ALREADY_REGISTERED") {
                    uiState.delegateAlreadyDone = true
                    addLog("ⓘ delegate skip: 이미 위임됨 (ALREADY_REGISTERED)")
                } else {
                    uiState.delegateError = msg
                    addLog("✗ delegate FAILED: \(msg)")
                }
            }
        }
    }

    func revoke(addressInput: String = "") {
        guard uiState.sdkInitialized else {
            uiState.delegateError = "SDK 가 초기화되지 않았습니다"
            return
        }
        let addr = addressInput.isEmpty ? address : addressInput
        if addr.isEmpty {
            uiState.delegateError = "address 가 필요합니다"
            return
        }
        uiState.delegateLoading = true
        uiState.delegateError = nil
        addLog("▶ revoke(address=\(addr))")

        Task {
            let result = await DSRVWallet.revoke(address: addr)
            uiState.delegateLoading = false
            switch result {
            case .success(let list):
                let successes = list.filter { $0.isSuccess }.count
                let failures = list.count - successes
                uiState.delegateResults = []
                uiState.delegateAlreadyDone = false
                uiState.approveResults = []
                if list.isEmpty {
                    addLog("ⓘ revoke skip: 위임된 체인 없음")
                } else {
                    addLog("✓ revoke (success=\(successes) / failed=\(failures) of \(list.count))")
                    for item in list {
                        if !item.isSuccess {
                            addLog("  ✗ \(item.chainId) [\(item.outcome)]: \(item.errorMessage ?? "unknown")")
                        } else if let h = item.txHash {
                            addLog("  ✓ \(item.chainId) [\(item.outcome)]: \(h)")
                        } else {
                            // ALREADY_DELEGATED / SKIPPED — txHash 없음
                            addLog("  ✓ \(item.chainId) [\(item.outcome)]")
                        }
                    }
                }
            case .failure(let error):
                uiState.delegateError = error.description
                addLog("✗ revoke FAILED: \(error.description)")
            }
        }
    }

    // MARK: - Approve

    /// 결제 컨트랙트로의 토큰 approve 셋업을 **지원 chain 전체**에 일괄 처리한다.
    /// 대상 token 은 WaaS 의 `project_assets` 에 등록된 활성 ERC-20 으로 자동 결정 (client 입력 없음).
    /// 위임이 사전에 설치되어 있어야 한다 (`delegate` 선행).
    ///
    /// - Parameter amountInput: "MAX" (unbounded) 또는 "0" (revoke). 비어 있으면 "MAX". SDK 가 uppercase 정규화.
    func approve(addressInput: String = "", amountInput: String = "") {
        guard uiState.sdkInitialized else {
            uiState.approveError = "SDK 가 초기화되지 않았습니다"
            return
        }
        let addr = addressInput.isEmpty ? address : addressInput
        if addr.isEmpty {
            uiState.approveError = "address 가 필요합니다 (createAddress 먼저 실행)"
            return
        }
        let amount = amountInput.isEmpty ? "MAX" : amountInput

        uiState.approveLoading = true
        uiState.approveError = nil
        uiState.approveResults = []
        addLog("▶ approve(address=\(addr.prefix(10))…, amount=\(amount))")

        Task {
            let result = await DSRVWallet.approve(address: addr, amount: amount)
            uiState.approveLoading = false
            switch result {
            case .success(let list):
                let successes = list.filter { $0.isSuccess }.count
                let failures = list.count - successes
                uiState.approveResults = list
                addLog("✓ approve (success=\(successes) / failed=\(failures) of \(list.count))")
                for item in list {
                    if !item.isSuccess {
                        addLog("  ✗ \(item.chainId) [\(item.outcome)]: \(item.errorMessage ?? "unknown")")
                    } else if let h = item.txHash {
                        addLog("  ✓ \(item.chainId) [\(item.outcome)]: \(h)")
                    } else {
                        // SKIPPED — txHash 없음
                        addLog("  ✓ \(item.chainId) [\(item.outcome)]")
                    }
                }
            case .failure(let error):
                uiState.approveError = error.description
                addLog("✗ approve FAILED: \(error.description)")
            }
        }
    }

    // MARK: - Payment (customer-backend POST /payments — TOPUP)

    /// customer-backend `POST /payments` 호출. 서버가 quote → paymentDigest 서명 → execute 를 통합 처리.
    ///
    /// 비어 있는 입력값은 합리적 default 로 채움:
    ///   sourceUserId → [userUuid] (raw userId 를 시드로 만든 결정적 UUID — WaaS 가 topup
    ///                  wallet 등록 시 external_user_ref 로 박는 값과 동일해야 매칭됨)
    ///   chainId      → 선택된 chain (없으면 demoChainIdFallback)
    ///   token        → 선택된 chain 의 USDC (TokenConfig)
    ///   from         → 현재 선택된 지갑 address
    ///   paymentType  → 0
    func pay(
        sourceUserIdInput: String = "",
        chainIdInput: String = "",
        tokenInput: String = "",
        fromInput: String = "",
        toInput: String,
        amountInput: String,
        paymentTypeInput: String = ""
    ) {
        guard uiState.sdkInitialized else {
            uiState.paymentError = "SDK 가 초기화되지 않았습니다"
            return
        }
        let from = fromInput.isEmpty ? address : fromInput
        if from.isEmpty {
            uiState.paymentError = "from 주소가 필요합니다 (create 먼저 실행)"
            return
        }
        if toInput.trimmingCharacters(in: .whitespaces).isEmpty {
            uiState.paymentError = "to 주소를 입력하세요 (SETTLEMENT 지갑)"
            return
        }
        if amountInput.trimmingCharacters(in: .whitespaces).isEmpty {
            uiState.paymentError = "amount (예: 1.5) 를 입력하세요"
            return
        }
        // raw userId 가 아닌 userUuid (UUID v3 derive) 사용 — wallet_topup.external_user_ref 와 일치시킴.
        let sourceUserId = sourceUserIdInput.isEmpty ? userUuid : sourceUserIdInput
        if sourceUserId.isEmpty {
            uiState.paymentError = "sourceUserId 가 필요합니다"
            return
        }
        let chainIdStr = chainIdInput.isEmpty
            ? (uiState.selectedChainId ?? demoChainIdFallback)
            : chainIdInput
        guard let chainIdInt = Int(chainIdStr) else {
            uiState.paymentError = "chainId 정수 변환 실패: \(chainIdStr)"
            return
        }
        let token: String
        if tokenInput.isEmpty {
            if let usdc = TokenConfig.getToken(chainId: chainIdStr, symbol: "USDC") {
                token = usdc.address
            } else {
                uiState.paymentError = "chainId=\(chainIdStr) 의 USDC 주소가 정의되지 않았습니다. token 직접 입력"
                return
            }
        } else {
            token = tokenInput
        }
        let paymentType = Int(paymentTypeInput) ?? 0

        let request = PaymentRequest(
            sourceUserId: sourceUserId,
            chainId: chainIdInt,
            token: token,
            from: from,
            to: toInput.trimmingCharacters(in: .whitespaces),
            amount: amountInput.trimmingCharacters(in: .whitespaces),
            paymentType: paymentType
        )

        uiState.paymentLoading = true
        uiState.paymentError = nil
        uiState.paymentResult = nil
        addLog("▶ pay(chainId=\(chainIdInt), from=\(from.prefix(10))…, to=\(request.to.prefix(10))…, amount=\(request.amount))")

        let repo = PaymentRepository(backendUrl: customerBackendUrl)
        Task {
            do {
                let response = try await repo.pay(request)
                uiState.paymentLoading = false
                uiState.paymentResult = response
                addLog("✓ pay status=\(response.status), txHash=\(response.txHash ?? "(pending)"), paymentUuid=\(response.paymentUuid)")
            } catch {
                uiState.paymentLoading = false
                uiState.paymentError = "\(error)"
                addLog("✗ pay FAILED: \(error)")
            }
        }
    }

    // MARK: - Restore

    func restore() {
        guard uiState.sdkInitialized else {
            uiState.restoreError = "SDK 가 초기화되지 않았습니다"
            return
        }
        uiState.restoreLoading = true
        uiState.restoreError = nil
        uiState.restoreResult = nil
        addLog("▶ restore()")

        Task {
            let result = await DSRVWallet.restore()
            uiState.restoreLoading = false
            switch result {
            case .success(let restored):
                let ok = restored.filter { $0.success }.count
                let fail = restored.filter { !$0.success }.count
                uiState.restoreResult = "복원 완료 (성공 \(ok) · 실패 \(fail))"
                addLog("✓ restore OK — 성공 \(ok) / 실패 \(fail)")
                restored.filter { !$0.success }.forEach {
                    addLog("  ✗ \($0.address.prefix(10))…: \($0.error ?? "")")
                }
                getAccountList()
            case .failure(let error):
                uiState.restoreError = error.description
                addLog("✗ restore FAILED: \(error.description)")
            }
        }
    }
}
