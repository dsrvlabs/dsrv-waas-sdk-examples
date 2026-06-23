import SwiftUI
import Foundation
import Combine
import CommonCrypto
import dsrv_wallet_sdk_ios

public enum Config {
    public static let customerBackendURL = "https://your-backend.com"
    public static let sdkId = "your-sdk-id"
    public static let dsrvApiBaseUrl: String = "https://api.dsrv.com"

    /// Passkey 백업/복원의 WebAuthn relying party 도메인 — 발급/운영 도메인으로 교체하세요.
    /// 같은 cloud account 의 device 간 backup 복원이 같은 namespace 에서 가능하려면 모든 빌드가 동일 값을 써야 함.
    public static let backupRpId: String = "your-backend.com"
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

    // Setup status — chain 별 위임·승인 상태 (읽기 전용)
    var setupStatusLoading: Bool = false
    var setupStatusError: String? = nil
    var setupStatus: [ChainSetupStatus] = []

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

    // Asset list (WaaS getAccountAssets, 선택 체인 필터) — 전송 드롭다운/자산조회/결제 공용.
    // 선택·KRW 같은 화면별 상태는 각 View 가 보관하고, 목록/로딩/에러만 여기서 관리한다.
    var assets: [AssetRow] = []
    var assetsLoading: Bool = false
    var assetsError: String? = nil

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

    /// View 에서 in-app 로그에 한 줄을 기록할 수 있게 노출한다.
    func log(_ message: String) {
        addLog(message)
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
            baseUrl: Config.dsrvApiBaseUrl,
            rpId: Config.backupRpId
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
    /// @param chainId         전송 체인 (선택된 자산의 chainId)
    /// @param contractAddress ERC-20 컨트랙트 주소. native 코인은 nil
    /// @param decimals        자산 decimals (price-hub 메타에서 획득)
    /// @param symbol          로그/표시용 심볼
    func transfer(
        recipientInput: String,
        amountInput: String,
        chainId: String,
        contractAddress: String?,
        decimals: Int,
        symbol: String = ""
    ) {
        guard uiState.sdkInitialized else {
            uiState.transferError = "SDK가 초기화되지 않았습니다"
            return
        }
        let addr = address
        if addr.isEmpty {
            uiState.transferError = "address 가 필요합니다"
            return
        }
        if chainId.isEmpty {
            uiState.transferError = "chainId 가 필요합니다 (자산을 먼저 선택하세요)"
            return
        }
        if recipientInput.trimmingCharacters(in: .whitespaces).isEmpty {
            uiState.transferError = "수신 주소를 입력하세요"
            return
        }
        let recipient = recipientInput

        let isNative = contractAddress?.isEmpty ?? true
        // decimals 미확인(price-hub 메타 실패/미지원 → 0)이면 base unit 변환이 왜곡(소수부 절단)되어
        // 의도보다 적게 전송될 수 있으므로 native·토큰 모두 전송을 차단한다(앱이 raw amount 를 직접 계산).
        if decimals <= 0 {
            uiState.transferError = "자산 decimals 를 확인하지 못했습니다. 자산을 새로고침한 뒤 다시 시도하세요."
            return
        }
        let defaultHuman = isNative ? "0.001" : "1"
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
        addLog("▶ transfer(\(symbol.isEmpty ? (isNative ? "native" : "token") : symbol), chainId=\(chainId), to=\(recipient.prefix(10))…, amount=\(humanAmount) → \(amount) base)")

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

    // MARK: - 자산 목록 (WaaS — RPC 직접호출 대체)

    enum AssetError: LocalizedError {
        case notReady(String)
        var errorDescription: String? {
            switch self { case .notReady(let m): return m }
        }
    }

    private var assetsLoadGeneration = 0

    /// 선택 계정/체인의 자산 목록을 조회해 `uiState.assets` 에 보관 (공용 상태). 화면(전송 드롭다운/
    /// 자산조회/결제)은 `uiState.assets` 를 관찰하고 선택·KRW 같은 화면별 상태만 각자 들고 있는다.
    /// 빠른 체인/계정 전환 시 stale 응답이 덮어쓰지 않도록 세대 가드를 둔다.
    func loadAssets() async {
        assetsLoadGeneration += 1
        let gen = assetsLoadGeneration
        uiState.assetsLoading = true
        uiState.assetsError = nil
        do {
            let rows = try await fetchAssetRows()
            guard gen == assetsLoadGeneration else { return }
            uiState.assets = rows
            uiState.assetsLoading = false
        } catch {
            guard gen == assetsLoadGeneration else { return }
            uiState.assets = []
            uiState.assetsError = error.localizedDescription
            uiState.assetsLoading = false
        }
    }

    /// 선택된 계정(accountId)의 자산 목록을 조회해 드롭다운용 `AssetRow` 로 만든다 (선택 체인 필터).
    ///
    /// 흐름: (1) customer-backend `GET /sdk/asset/accounts/{accountId}` 로 계정의 모든 주소·체인
    /// 잔고(합산) 조회 → (2) 자산별 price-hub `by-chain/latest-value` 로 decimals(+없는 symbol) 보완
    /// → (3) decimals 로 휴머나이즈. symbol 은 WaaS 가 주면 우선, decimals 는 WaaS 가 안 줘서 price-hub.
    /// ETH/USDC 하드코딩(`TokenConfig`)·RPC(`BalanceClient`) 제거.
    func fetchAssetRows() async throws -> [AssetRow] {
        guard let accountId = uiState.selectedAccountId, !accountId.isEmpty else {
            throw AssetError.notReady("계정을 먼저 선택하세요 (getAccountList)")
        }
        // 계정 자산 API 는 계정의 '모든 주소·체인' 잔고를 합산 반환하므로 선택된 체인으로 필터.
        let chainId = uiState.selectedChainId ?? ""
        let backend = customerBackendUrl
        let listRepo = AccountAssetRepository(backendUrl: backend)
        let resp = try await listRepo.getAccountAssets(accountId: accountId)

        let valueRepo = AssetValueRepository(backendUrl: backend)
        // 선택된 체인의 자산만 — symbol 은 WaaS 가 주면 우선, decimals(+없는 symbol)는 price-hub 보완.
        var rows: [AssetRow] = []
        for item in resp.items where item.chainId == chainId {
            rows.append(await buildAssetRow(item: item, valueRepo: valueRepo))
        }
        // native 를 먼저, 그다음 심볼 사전순.
        return rows.sorted { lhs, rhs in
            if lhs.isNative != rhs.isNative { return lhs.isNative }
            return lhs.symbol.localizedCaseInsensitiveCompare(rhs.symbol) == .orderedAscending
        }
    }

    /// 자산 1건 → `AssetRow`. decimals 는 WaaS 가 안 주므로 항상 price-hub 에서 받고, 없으면(미지원/실패)
    /// native 는 체인 계열별 고정값(EVM=18, SVM=9)으로, 토큰은 0(decimals 미상, raw 표시)으로 폴백한다 — 토큰은 0 이면 전송이 차단된다(`transfer`).
    /// 잔액은 항상 노출하고 KRW 만 비운다(기존 graceful 동작 유지).
    func buildAssetRow(item: AccountAssetItem, valueRepo: AssetValueRepository) async -> AssetRow {
        let isNative = item.contractAddress?.isEmpty ?? true
        // 심볼 우선순위: ① WaaS(item.symbol, 정확) ② price-hub ③ 체인 계열 fallback(EVM→ETH).
        let waasSymbol = item.symbol?.trimmingCharacters(in: .whitespaces)
        let hasWaasSymbol = !(waasSymbol?.isEmpty ?? true)
        let fallbackSymbol = isNative ? Wallet.nativeFallbackSymbol(chainType: item.chainType) : "TOKEN"
        var symbol = hasWaasSymbol ? waasSymbol!.uppercased() : fallbackSymbol
        var name = symbol
        var decimals = 0
        do {
            // decimals 는 WaaS 가 안 주므로 항상 price-hub 에서 받는다. symbol 은 WaaS 가 없을 때만 보완.
            let meta = try await valueRepo.getLatestValue(
                chainId: item.chainId,
                contractAddress: item.contractAddress,
                amount: nil
            )
            if !hasWaasSymbol {
                let metaSymbol = meta.asset.symbol.trimmingCharacters(in: .whitespaces)
                if !metaSymbol.isEmpty { symbol = metaSymbol.uppercased() }
            }
            if !meta.asset.name.isEmpty { name = meta.asset.name }
            decimals = meta.asset.decimals ?? 0
        } catch {
            // price-hub 미지원/실패 — symbol 은 위에서 정한 값(WaaS or fallback), decimals 는 fallback 유지.
        }
        // native 코인은 decimals 가 체인 계열별로 고정(EVM=18, SVM=9)이므로 price-hub 가 못 줬을 때 그 값으로 폴백한다.
        // 이러면 화면 표시가 raw 대신 사람이 읽는 값으로 humanize 되고, 전송 시 base unit 변환도 정상화된다.
        if isNative && decimals <= 0 {
            decimals = Wallet.nativeFallbackDecimals(chainType: item.chainType)
        }
        let humanized = decimals > 0 ? fromBaseUnits(item.balance, decimals: decimals) : item.balance
        return AssetRow(
            chainId: item.chainId,
            contractAddress: isNative ? nil : item.contractAddress,
            rawBalance: item.balance,
            symbol: symbol,
            name: name,
            decimals: decimals,
            humanizedBalance: humanized
        )
    }

    /// price-hub·WaaS 둘 다 심볼을 못 줄 때 native 코인의 표시 심볼 — 체인 계열 기준.
    /// 현재 지원 체인은 모두 EVM=ETH. WaaS 가 symbol 을 주면 그 값이 최우선이라 이 fallback 은 거의 안 쓰임.
    static func nativeFallbackSymbol(chainType: String) -> String {
        switch chainType.uppercased() {
        case "SVM", "SOLANA": return "SOL"
        default: return "ETH"
        }
    }

    /// price-hub 가 native 코인 decimals 를 못 줄 때의 체인 계열별 기본값 — EVM=18(wei), SVM=9(lamport).
    /// 모든 native 를 18 로 강제하면 Solana 가 10^9 배 왜곡되므로 체인 계열로 분기한다.
    static func nativeFallbackDecimals(chainType: String) -> Int {
        switch chainType.uppercased() {
        case "SVM", "SOLANA": return 9
        default: return 18
        }
    }

    // MARK: - 자산 가치 (KRW 환산)

    /// 보유분 KRW 환산값 — 포맷된 "₩..." 문자열, 시세 미가용/실패 시 nil.
    /// 잔액 RPC 조회는 View 가, 가치 조회+포맷은 여기서 담당한다 (Android `Wallet.getKrwValue` 와 동일).
    /// 자체 do/catch 로 실패를 흡수하므로 호출 측 잔액 표시 흐름과 독립적이다.
    func getKrwValue(chainId: String, contractAddress: String?, amount: String) async -> String? {
        let contractLabel = (contractAddress?.isEmpty == false) ? contractAddress! : "NATIVE"
        do {
            // 잔액 0 → 0개 × 단가 = ₩0. 백엔드는 amount=0 이면 holdings 를 생략하므로 직접 표시.
            if (Decimal(string: amount) ?? .zero) == .zero {
                return formatKrw("0")
            }
            let repo = AssetValueRepository(backendUrl: customerBackendUrl)
            let value = try await repo.getLatestValue(
                chainId: chainId,
                contractAddress: contractAddress,
                amount: amount
            )
            guard let total = value.holdings?.totalValue else {
                log("⚠ KRW 시세 미가용: chainId=\(chainId) contract=\(contractLabel)")
                return nil
            }
            return formatKrw(total)
        } catch {
            log("✗ KRW 환산 실패: chainId=\(chainId) contract=\(contractLabel) — \(error.localizedDescription)")
            return nil
        }
    }

    // totalValue 는 BigDecimal 문자열 — Double 변환 없이 Decimal 로 파싱해 정밀도 손실을 피한다.
    private func formatKrw(_ value: String) -> String {
        let decimal = Decimal(string: value) ?? .zero
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        // 기본값 .halfEven 은 0.005→0.00 으로 내려 Android(HALF_UP)/Flutter(수동 half-up) 와 어긋난다.
        formatter.roundingMode = .halfUp
        let formatted = formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? value
        return "₩" + formatted
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
                getSetupStatus(addressInput: addr)
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
                getSetupStatus(addressInput: addr)
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
                getSetupStatus(addressInput: addr)
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

    // MARK: - Setup status (읽기 전용 — chain 별 위임·승인 상태)

    /// 선택된 address 의 (accountId, addressId) 를 accounts 목록에서 역조회.
    /// getSetupStatus 는 path 식별자로 둘 다 필요하다.
    private func resolveAccountAddressId(for addr: String) -> (accountId: String, addressId: String)? {
        let normalized = addr.lowercased()
        for acc in uiState.accounts {
            if let a = acc.addresses.first(where: { $0.address.lowercased() == normalized }) {
                return (acc.accountId, a.addressId)
            }
        }
        return nil
    }

    /// 선택 address 의 chain 별 위임·승인 상태를 조회한다. approve/revoke/delegate 직후 갱신 호출.
    func getSetupStatus(addressInput: String = "") {
        guard uiState.sdkInitialized else {
            uiState.setupStatusError = "SDK 가 초기화되지 않았습니다"
            return
        }
        let addr = addressInput.isEmpty ? address : addressInput
        if addr.isEmpty {
            uiState.setupStatusError = "address 가 필요합니다 (지갑을 먼저 선택)"
            return
        }
        guard let ids = resolveAccountAddressId(for: addr) else {
            uiState.setupStatusError = "addressId 를 찾지 못했습니다 (getAccountList 먼저 실행)"
            return
        }
        uiState.setupStatusLoading = true
        uiState.setupStatusError = nil
        addLog("▶ getSetupStatus(address=\(addr.prefix(10))…)")

        Task {
            let result = await DSRVWallet.getSetupStatus(accountId: ids.accountId, addressId: ids.addressId)
            uiState.setupStatusLoading = false
            switch result {
            case .success(let list):
                uiState.setupStatus = list
                addLog("✓ getSetupStatus count=\(list.count)")
                for c in list {
                    addLog("  chainId=\(c.chainId), delegated=\(c.delegated), tokens=\(c.approvals.count)")
                }
            case .failure(let error):
                uiState.setupStatusError = error.description
                addLog("✗ getSetupStatus FAILED: \(error.description)")
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
    ///   token        → PaymentSection 이 선택한 자산의 컨트랙트 주소 (필수)
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
        // token 은 결제할 자산의 컨트랙트 주소 — PaymentSection 이 선택 자산에서 직접 전달한다.
        let token = tokenInput
        if token.isEmpty {
            uiState.paymentError = "token(컨트랙트 주소)이 필요합니다 (자산을 먼저 선택하세요)"
            return
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
