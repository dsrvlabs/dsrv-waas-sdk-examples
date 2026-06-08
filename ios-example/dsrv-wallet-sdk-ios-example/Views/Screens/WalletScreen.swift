import SwiftUI
import dsrv_wallet_sdk_ios

// MARK: - 화면 라우팅

private enum AppScreen: Equatable {
    case login
    case walletList
    case walletDetail
    case feature(Feature)

    enum Feature: String, CaseIterable, Equatable {
        case query, smartAccount, backup, transfer, history, payment, log
        var title: String {
            switch self {
            case .query: return "지갑 조회"
            case .smartAccount: return "스마트어카운트"
            case .backup: return "백업 / 복원"
            case .transfer: return "전송"
            case .history: return "거래 내역"
            case .payment: return "결제"
            case .log: return "로그"
            }
        }
        var iconName: String {
            switch self {
            case .query: return "wallet.pass"
            case .smartAccount: return "checkmark.shield"
            case .backup: return "icloud.and.arrow.up"
            case .transfer: return "paperplane"
            case .history: return "clock.arrow.circlepath"
            case .payment: return "creditcard"
            case .log: return "doc.text"
            }
        }
        var description: String {
            switch self {
            case .query: return "지갑 주소·체인 정보"
            case .smartAccount: return "위임(EIP-7702) · 승인"
            case .backup: return "백업 · 복원 · 키 갱신"
            case .transfer: return "ETH · ERC-20 전송"
            case .history: return "거래 내역 조회"
            case .payment: return "Topup 결제"
            case .log: return "SDK · backend trace"
            }
        }
    }
}

// MARK: - WalletScreen (라우터)

struct WalletScreen: View {
    @EnvironmentObject var wallet: Wallet
    @State private var screen: AppScreen = .login

    var body: some View {
        Group {
            switch screen {
            case .login:
                LoginScreen(onLogin: { screen = .walletList })
            case .walletList:
                WalletListScreen(
                    onBack: { screen = .login },
                    onWalletSelected: { screen = .walletDetail }
                )
            case .walletDetail:
                WalletDetailScreen(
                    onBack: { screen = .walletList },
                    onFeature: { screen = .feature($0) }
                )
            case .feature(let f):
                FeatureScreen(feature: f, onBack: { screen = .walletDetail })
            }
        }
        .onAppear {
            if wallet.userId.isEmpty { screen = .login }
        }
        .onChange(of: wallet.userId) { newValue in
            if newValue.isEmpty { screen = .login }
        }
        .onChange(of: wallet.uiState.sdkInitialized) { initialized in
            if !initialized && screen != .login {
                screen = wallet.userId.isEmpty ? .login : .walletList
            }
        }
        .onChange(of: wallet.publicKey) { pk in
            if pk.isEmpty {
                switch screen {
                case .walletDetail, .feature: screen = .walletList
                default: break
                }
            }
        }
    }
}

// MARK: - Screen 1: Login

private struct LoginScreen: View {
    @EnvironmentObject var wallet: Wallet
    let onLogin: () -> Void

    @State private var input: String = ""
    @State private var loginAttempted = false

    private var derivedUuid: String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "" : Wallet.userIdToUuid(trimmed)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("사용자 식별").font(.title2.bold())
                    Text("임의의 userId 를 입력하면 결정적 UUID 가 생성됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SectionCard("사용자 ID") {
                        TextField("userId (예: alice@example.com)", text: $input)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("생성된 UUID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(derivedUuid.isEmpty ? "userId 를 입력하세요" : derivedUuid)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(derivedUuid.isEmpty ? .secondary : .primary)
                    }

                    SectionCard("SDK / 백엔드") {
                        KeyValueRow(label: "SDK ID", value: wallet.sdkId)
                        KeyValueRow(label: "Backend", value: wallet.customerBackendUrl)
                    }

                    Button {
                        let trimmed = input.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        loginAttempted = true
                        if trimmed != wallet.userId {
                            wallet.changeUserId(trimmed)
                        }
                        if wallet.uiState.sdkInitialized {
                            onLogin()
                        } else {
                            wallet.retryInitialize()
                        }
                    } label: {
                        buttonLabel(
                            wallet.uiState.sdkInitializing ? "초기화 중…" : "로그인",
                            loading: wallet.uiState.sdkInitializing,
                            style: .filled
                        )
                    }
                    .disabled(derivedUuid.isEmpty || wallet.uiState.sdkInitializing)

                    if let err = wallet.uiState.sdkInitError {
                        Text("⚠ \(err)")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    if !wallet.userId.isEmpty {
                        Button {
                            wallet.resetWallet()
                            input = ""
                        } label: {
                            buttonLabel("저장된 사용자 초기화", loading: false, style: .outlined)
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("로그인")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            input = wallet.userId
        }
        .onChange(of: wallet.uiState.sdkInitialized) { initialized in
            if initialized && loginAttempted { onLogin() }
        }
    }
}

// MARK: - Screen 2: WalletList

private struct WalletListScreen: View {
    @EnvironmentObject var wallet: Wallet
    let onBack: () -> Void
    let onWalletSelected: () -> Void

    private var canProceed: Bool { !wallet.publicKey.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        ChainSection()
                        AccountSection()
                    }
                    .padding(16)
                }

                bottomBar
            }
            .navigationTitle("지갑 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onBack() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("지갑 선택").font(.headline)
                        Text("userId: \(wallet.userId.isEmpty ? "(none)" : wallet.userId)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if wallet.uiState.sdkInitialized
                && wallet.uiState.accounts.isEmpty
                && !wallet.uiState.accountsLoading {
                wallet.getAccountList()
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 6) {
            if canProceed {
                Text("선택된 지갑: \(shortHex(wallet.address))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                onWalletSelected()
            } label: {
                buttonLabel(
                    canProceed ? "선택" : "지갑을 먼저 선택하세요",
                    loading: false,
                    style: .filled
                )
            }
            .disabled(!canProceed)
        }
        .padding(16)
        .background(Color(.systemBackground).shadow(radius: 1))
    }
}

// MARK: - Screen 3: WalletDetail

private struct WalletDetailScreen: View {
    @EnvironmentObject var wallet: Wallet
    let onBack: () -> Void
    let onFeature: (AppScreen.Feature) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalletSummaryCard()
                    Text("기능 테스트")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    FeatureMenu(onSelect: onFeature)
                }
                .padding(16)
            }
            .navigationTitle("지갑 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onBack() } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

private struct WalletSummaryCard: View {
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var toast: ToastManager

    @State private var qrOpen = false

    private var account: AccountInfo? {
        wallet.uiState.accounts.first { $0.accountId == wallet.uiState.selectedAccountId }
    }
    private var chain: ChainInfo? {
        wallet.uiState.chains.first { $0.chainId == wallet.uiState.selectedChainId }
    }

    var body: some View {
        SectionCard(account?.label ?? "(계정 없음)") {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.map { "id \(shortHex($0.accountId))" } ?? "계정 미선택")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let chain {
                    Text(chain.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text("지갑 주소")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(wallet.address.isEmpty ? "(지갑 미발급)" : wallet.address)
                .font(.subheadline.monospaced())

            if !wallet.address.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = wallet.address
                        toast.show("복사됨")
                    } label: {
                        buttonLabel("주소 복사", loading: false, style: .outlined)
                    }
                    Button {
                        qrOpen = true
                    } label: {
                        buttonLabel("QR", loading: false, style: .outlined)
                    }
                }
            }
        }
        .sheet(isPresented: $qrOpen) {
            VStack(spacing: 12) {
                Text("내 지갑 주소").font(.headline).padding(.top, 24)
                QRCodeView(content: wallet.address, size: 240)
                Text(wallet.address)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                Button("닫기") { qrOpen = false }
                    .padding(.top, 12)
                Spacer()
            }
            .presentationDetents([.medium, .large])
        }
    }
}

private struct FeatureMenu: View {
    let onSelect: (AppScreen.Feature) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppScreen.Feature.allCases.enumerated()), id: \.offset) { idx, f in
                Button {
                    onSelect(f)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: f.iconName)
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.title).font(.subheadline)
                            Text(f.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < AppScreen.Feature.allCases.count - 1 { Divider() }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Screen 4: Feature

private struct FeatureScreen: View {
    let feature: AppScreen.Feature
    let onBack: () -> Void

    var body: some View {
        NavigationStack {
            featureBody
                .navigationTitle(feature.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { onBack() } label: { Image(systemName: "chevron.left") }
                    }
                }
        }
    }

    @ViewBuilder
    private var featureBody: some View {
        switch feature {
        case .log:
            VStack {
                LogSection()
            }
            .padding(16)
        default:
            ScrollView {
                VStack(spacing: 16) {
                    switch feature {
                    case .query: QueryFeature()
                    case .smartAccount: SmartAccountFeature()
                    case .backup: BackupFeature()
                    case .transfer: TransferFeature()
                    case .history: HistoryFeature()
                    case .payment: PaymentFeature()
                    case .log: EmptyView()
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Feature subviews

private struct QueryFeature: View {
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var toast: ToastManager

    private var chain: ChainInfo? {
        wallet.uiState.chains.first { $0.chainId == wallet.uiState.selectedChainId }
    }

    var body: some View {
        SectionCard("주소 정보") {
            KeyValueRow(label: "Public Key", value: wallet.publicKey)
            KeyValueRow(label: "Address", value: wallet.address)
            KeyValueRow(label: "Chain", value: chain.map { "\($0.name) (\($0.chainId))" } ?? "(미선택)")
            if let c = chain {
                KeyValueRow(label: "Type", value: "\(c.chainType) / \(c.networkType)")
            }
        }

        HStack(spacing: 8) {
            Button {
                UIPasteboard.general.string = wallet.address
                toast.show("주소 복사됨")
            } label: {
                buttonLabel("주소 복사", loading: false, style: .outlined)
            }
            .disabled(wallet.address.isEmpty)

            Button {
                wallet.getAccountList()
            } label: {
                buttonLabel(
                    "계정 새로고침",
                    loading: wallet.uiState.accountsLoading,
                    style: .outlined
                )
            }
            .disabled(!wallet.uiState.sdkInitialized || wallet.uiState.accountsLoading)
        }

        if !wallet.address.isEmpty {
            SectionCard("QR 코드") {
                HStack {
                    Spacer()
                    QRCodeView(content: wallet.address, size: 200)
                    Spacer()
                }
                Text(wallet.address)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }

        Text("ⓘ 잔액 조회는 RPC 직접 호출이 필요합니다.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SmartAccountFeature: View {
    var body: some View {
        DelegateSection()
        ApproveSection()
    }
}

private struct BackupFeature: View {
    var body: some View {
        Text("키 관리")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        BackupSection()
        RestoreSection()
    }
}

private struct TransferFeature: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        if wallet.publicKey.isEmpty {
            InfoBanner(text: "지갑을 먼저 선택하세요.")
        } else {
            TransferSection()
        }
    }
}

private struct HistoryFeature: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        if wallet.publicKey.isEmpty {
            InfoBanner(text: "지갑을 먼저 선택하세요.")
        } else {
            HistorySection()
        }
    }
}

private struct PaymentFeature: View {
    @EnvironmentObject var wallet: Wallet

    var body: some View {
        if wallet.publicKey.isEmpty {
            InfoBanner(text: "지갑을 먼저 선택하세요.")
        } else {
            PaymentSection()
        }
    }
}

// MARK: - 공용 유틸

private func shortHex(_ s: String) -> String {
    s.count <= 16 ? s : "\(s.prefix(10))…\(s.suffix(4))"
}
