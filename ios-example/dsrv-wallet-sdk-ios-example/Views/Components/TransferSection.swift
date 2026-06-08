import SwiftUI
import dsrv_wallet_sdk_ios

struct TransferSection: View {
    @EnvironmentObject var wallet: Wallet

    @State private var recipient: String = ""
    @State private var amount: String = ""
    @State private var tokenIndex: Int = 0
    @State private var scannerOpen = false
    @State private var confirmOpen = false

    @State private var balanceText: String? = nil
    @State private var balanceLoading = false
    @State private var balanceError: String? = nil

    private let balanceClient = BalanceClient()

    private var chainId: String { wallet.uiState.selectedChainId ?? "" }
    private var chain: ChainInfo? {
        wallet.uiState.chains.first(where: { $0.chainId == chainId })
    }
    private var tokens: [String] {
        ["ETH"] + TokenConfig.getAvailableTokenSymbols(chainId)
    }
    private var token: String {
        let i = min(max(tokenIndex, 0), max(tokens.count - 1, 0))
        return tokens.indices.contains(i) ? tokens[i] : "ETH"
    }
    private var tokenInfo: TokenInfo? {
        token == "ETH" ? nil : TokenConfig.getToken(chainId: chainId, symbol: token)
    }

    var body: some View {
        SectionCard("전송", subtitle: "체인 \(chain?.name ?? "없음") · \(token)") {
            // 토큰 segmented
            Picker("토큰", selection: $tokenIndex) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { idx, t in
                    Text(t).tag(idx)
                }
            }
            .pickerStyle(.segmented)

            tokenInfoView

            balanceRow

            HStack(spacing: 8) {
                TextField("받는 주소", text: $recipient)
                    .textFieldStyle(.roundedBorder)
                Button("QR 스캔") { scannerOpen = true }
                    .font(.footnote)
            }

            TextField(
                token == "ETH" ? "금액 (ETH, 기본 0.001)" : "금액 (\(token), 기본 1)",
                text: $amount
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)

            Button {
                if recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                    wallet.transfer(recipientInput: recipient, amountInput: amount, tokenSymbol: token)
                } else {
                    confirmOpen = true
                }
            } label: {
                buttonLabel("거래 확인", loading: wallet.uiState.transferLoading, style: .filled)
            }
            .disabled(!wallet.uiState.sdkInitialized || wallet.uiState.transferLoading)

            if let hash = wallet.uiState.lastTxHash {
                Text("✓ 전송 완료").font(.caption).foregroundColor(.green)
                CopyableText(text: hash, singleLine: true)
            }
            if let err = wallet.uiState.transferError {
                ErrorLine(message: err)
            }
        }
        .onAppear { Task { await refreshBalance() } }
        .onChange(of: token) { _ in Task { await refreshBalance() } }
        .onChange(of: chainId) { _ in Task { await refreshBalance() } }
        .onChange(of: wallet.address) { _ in Task { await refreshBalance() } }
        .sheet(isPresented: $scannerOpen) {
            QRScannerSheet(
                onScanned: { value in
                    recipient = parseRecipient(value)
                    scannerOpen = false
                },
                onClose: { scannerOpen = false }
            )
        }
        .alert("거래 확인", isPresented: $confirmOpen) {
            Button("취소", role: .cancel) { confirmOpen = false }
            Button("서명 & 전송") {
                confirmOpen = false
                wallet.transfer(recipientInput: recipient, amountInput: amount, tokenSymbol: token)
            }
        } message: {
            let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty
                ? (token == "ETH" ? "0.001" : "1") : amount
            return Text("받는 사람: \(recipient)\n금액: \(effective) \(token)\n체인: \(chain?.name ?? "?")\n\n⚠ 서명 후 되돌릴 수 없습니다.")
        }
    }

    @ViewBuilder
    private var tokenInfoView: some View {
        if token == "ETH" {
            Text("네이티브 코인 (gas 토큰) · decimals 18")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let info = tokenInfo {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(info.name) · decimals \(info.decimals)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(info.address)
                    .font(.caption.monospaced())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("이 체인에 정의된 \(token) 토큰 정보가 없습니다")
                .font(.caption)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var balanceRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("현재 잔액").font(.caption).foregroundStyle(.secondary)
                if balanceLoading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("조회 중…").font(.footnote)
                    }
                } else if let err = balanceError {
                    Text(err).font(.footnote).foregroundColor(.red)
                } else if let b = balanceText {
                    Text(b).font(.subheadline)
                } else {
                    Text("—").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("새로고침") { Task { await refreshBalance() } }
                .font(.footnote)
                .disabled(balanceLoading)
        }
    }

    private func refreshBalance() async {
        if chainId.isEmpty || wallet.address.isEmpty {
            balanceText = nil
            balanceError = chainId.isEmpty || wallet.address.isEmpty ? "체인·지갑 없음" : nil
            return
        }
        if TokenConfig.getRpcUrl(chainId) == nil {
            balanceError = "이 체인의 RPC 가 등록되지 않았습니다"
            return
        }
        balanceLoading = true
        balanceError = nil
        do {
            let display: String
            if token == "ETH" {
                let raw = try await balanceClient.getNativeBalance(chainId: chainId, address: wallet.address)
                display = fromBaseUnits(raw, decimals: 18) + " ETH"
            } else if let info = tokenInfo {
                let raw = try await balanceClient.getErc20Balance(chainId: chainId, tokenAddress: info.address, ownerAddress: wallet.address)
                display = fromBaseUnits(raw, decimals: info.decimals) + " \(token)"
            } else {
                throw BalanceClient.BalanceError.malformedResponse("토큰 정보 없음")
            }
            balanceText = display
        } catch {
            balanceError = error.localizedDescription
        }
        balanceLoading = false
    }
}

func parseRecipient(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    if trimmed.lowercased().hasPrefix("ethereum:") {
        let rest = String(trimmed.dropFirst("ethereum:".count))
        return rest.components(separatedBy: "@").first?
            .components(separatedBy: "/").first?
            .components(separatedBy: "?").first ?? rest
    }
    return trimmed
}

struct QRScannerSheet: View {
    let onScanned: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QRScannerView(onScanned: onScanned, onClose: onClose)
                .ignoresSafeArea()
            Button("닫기", action: onClose)
                .padding(16)
                .foregroundColor(.white)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
