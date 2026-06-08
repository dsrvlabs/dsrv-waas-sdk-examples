import SwiftUI
import dsrv_wallet_sdk_ios

/// Android `PaymentSection.kt` 대응 — customer-backend `POST /payments` 호출 (Topup 결제).
///
/// UI 는 `TransferSection` 패턴 — chain 자동(selectedChainId), 토큰은 ERC-20 segmented row
/// (USDC 등) 노출. amount 는 사람 읽는 단위(humanized, 예: "1.5") 그대로 전송 — wei 변환은
/// stablecoin Payments 측이 담당. paymentType=0, sourceUserId=wallet.userId, from=wallet.address
/// 는 `Wallet.pay` 가 자동 채움.
struct PaymentSection: View {
    @EnvironmentObject var wallet: Wallet

    @State private var to: String = ""
    @State private var amount: String = ""
    @State private var tokenIndex: Int = 0
    @State private var scannerOpen = false
    @State private var confirmOpen = false

    private var chainId: String { wallet.uiState.selectedChainId ?? "" }
    private var chain: ChainInfo? {
        wallet.uiState.chains.first(where: { $0.chainId == chainId })
    }
    private var tokens: [String] {
        TokenConfig.getAvailableTokenSymbols(chainId)
    }
    private var token: String? {
        let i = min(max(tokenIndex, 0), max(tokens.count - 1, 0))
        return tokens.indices.contains(i) ? tokens[i] : nil
    }
    private var tokenInfo: TokenInfo? {
        guard let token = token else { return nil }
        return TokenConfig.getToken(chainId: chainId, symbol: token)
    }

    var body: some View {
        SectionCard("결제 (Topup)", subtitle: "체인 \(chain?.name ?? "없음") · \(token ?? "토큰 없음")") {
            if tokens.isEmpty {
                Text("이 체인에 정의된 ERC-20 토큰이 없습니다 (TokenConfig 확인)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Picker("토큰", selection: $tokenIndex) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { idx, t in
                        Text(t).tag(idx)
                    }
                }
                .pickerStyle(.segmented)

                tokenInfoView
            }

            HStack(spacing: 8) {
                TextField("to (SETTLEMENT 지갑)", text: $to)
                    .textFieldStyle(.roundedBorder)
                Button("QR 스캔") { scannerOpen = true }
                    .font(.footnote)
            }

            TextField("금액 (\(token ?? "토큰"), 기본 1)", text: $amount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Button {
                guard !to.trimmingCharacters(in: .whitespaces).isEmpty, tokenInfo != nil else { return }
                confirmOpen = true
            } label: {
                buttonLabel("거래 확인", loading: wallet.uiState.paymentLoading, style: .filled)
            }
            .disabled(
                !wallet.uiState.sdkInitialized
                    || wallet.publicKey.isEmpty
                    || tokenInfo == nil
                    || to.trimmingCharacters(in: .whitespaces).isEmpty
                    || wallet.uiState.paymentLoading
            )

            if let r = wallet.uiState.paymentResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("✓ status=\(r.status)").font(.caption)
                    Text("transactionId").font(.caption2).foregroundStyle(.secondary)
                    CopyableText(text: r.transactionId, singleLine: true)
                    Text("paymentUuid").font(.caption2).foregroundStyle(.secondary)
                    CopyableText(text: r.paymentUuid, singleLine: true)
                    if let hash = r.txHash, !hash.isEmpty {
                        Text("txHash").font(.caption2).foregroundStyle(.secondary)
                        CopyableText(text: hash, singleLine: true)
                    }
                    if let submittedAt = r.submittedAt {
                        Text("submittedAt=\(submittedAt)").font(.caption2)
                    }
                }
            }
            if let err = wallet.uiState.paymentError {
                ErrorLine(message: err)
            }
        }
        .sheet(isPresented: $scannerOpen) {
            QRScannerSheet(
                onScanned: { value in
                    to = parseRecipient(value)
                    scannerOpen = false
                },
                onClose: { scannerOpen = false }
            )
        }
        .alert("결제 확인", isPresented: $confirmOpen) {
            Button("취소", role: .cancel) { confirmOpen = false }
            Button("결제") {
                confirmOpen = false
                guard let info = tokenInfo else { return }
                // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
                let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : amount
                wallet.pay(
                    chainIdInput: chainId,
                    tokenInput: info.address,
                    toInput: to,
                    amountInput: effective
                )
            }
        } message: {
            let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : amount
            return Text("받는 사람: \(to)\n금액: \(effective) \(token ?? "")\n체인: \(chain?.name ?? "?")\n\n⚠ 결제 후 되돌릴 수 없습니다.")
        }
    }

    @ViewBuilder
    private var tokenInfoView: some View {
        if let info = tokenInfo {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(info.name) · decimals \(info.decimals)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(info.address)
                    .font(.caption.monospaced())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
