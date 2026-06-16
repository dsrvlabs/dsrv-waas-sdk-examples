import SwiftUI
import dsrv_wallet_sdk_ios

/// Android `PaymentSection.kt` 대응 — customer-backend `POST /payments` 호출 (Topup 결제).
///
/// 결제(topup)는 stablecoin Payments 레일이라 **USDC 전용**입니다 (native·기타 토큰은 upstream
/// `CreateQuoteRequest` 가 ERC-20 컨트랙트 주소를 강제 — 미지원). 토큰은 USDC 로 고정(체인별 주소
/// 하드코딩), 잔액은 공용 `Wallet.uiState.assets` 에서 USDC 를 찾아 표시, KRW 는 price-hub.
/// chainId/token(USDC 주소)은 여기서, paymentType=0/sourceUserId/from 은 `Wallet.pay` 가 채움.
struct PaymentSection: View {
    @EnvironmentObject var wallet: Wallet

    @State private var to: String = ""
    @State private var amount: String = ""
    @State private var scannerOpen = false
    @State private var confirmOpen = false
    @State private var krwText: String? = nil
    @State private var krwLoading = false
    @State private var krwGeneration = 0

    private var chainId: String { wallet.uiState.selectedChainId ?? "" }
    private var chain: ChainInfo? {
        wallet.uiState.chains.first(where: { $0.chainId == chainId })
    }
    /// 결제 토큰 = 선택 체인의 USDC (하드코딩). stablecoin 측이 USDC 만 허용.
    private var usdcAddress: String? { PaymentSection.usdcAddress(chainId: chainId) }
    /// 공용 자산 목록에서 USDC 를 찾는다(없으면 nil → 잔액 0). 목록 적재는 `wallet.loadAssets()`.
    private var usdc: AssetRow? {
        guard let addr = usdcAddress else { return nil }
        return wallet.uiState.assets.first {
            ($0.contractAddress ?? "").caseInsensitiveCompare(addr) == .orderedSame
        }
    }
    private var balanceDisplay: String { usdc?.humanizedBalance ?? "0" }

    /// 체인별 USDC 컨트랙트 주소 (topup 전용 하드코딩). 미지원 체인은 nil.
    static func usdcAddress(chainId: String) -> String? {
        switch chainId {
        case "11155111": return "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"  // Ethereum Sepolia
        case "84532": return "0x036CbD53842c5426634e7929541eC2318f3dCF7e"     // Base Sepolia
        case "1": return "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"          // Ethereum Mainnet
        case "8453": return "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"       // Base Mainnet
        default: return nil
        }
    }

    var body: some View {
        SectionCard("결제 (Topup)", subtitle: "체인 \(chain?.name ?? (chainId.isEmpty ? "없음" : chainId)) · USDC") {
            if let usdcAddr = usdcAddress {
                balanceRow

                Text(usdcAddr)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    TextField("to (SETTLEMENT 지갑)", text: $to)
                        .textFieldStyle(.roundedBorder)
                    Button("QR 스캔") { scannerOpen = true }
                        .font(.footnote)
                }

                TextField("금액 (USDC, 기본 1)", text: $amount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                Button {
                    guard !to.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    confirmOpen = true
                } label: {
                    buttonLabel("거래 확인", loading: wallet.uiState.paymentLoading, style: .filled)
                }
                .disabled(
                    !wallet.uiState.sdkInitialized
                        || wallet.publicKey.isEmpty
                        || to.trimmingCharacters(in: .whitespaces).isEmpty
                        || wallet.uiState.paymentLoading
                )
            } else {
                Text("이 체인은 USDC topup 을 지원하지 않습니다")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
        .onAppear { Task { await wallet.loadAssets() } }
        .onChange(of: wallet.address) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.selectedAccountId) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.selectedChainId) { _ in Task { await wallet.loadAssets() } }
        .onChange(of: wallet.uiState.assets) { _ in Task { await refreshKrw() } }
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
                guard let usdcAddr = usdcAddress else { return }
                // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
                let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : amount
                wallet.pay(
                    chainIdInput: chainId,
                    tokenInput: usdcAddr,
                    toInput: to,
                    amountInput: effective
                )
            }
        } message: {
            let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : amount
            return Text("받는 사람: \(to)\n금액: \(effective) USDC\n체인: \(chain?.name ?? (chainId.isEmpty ? "?" : chainId))\n\n⚠ 결제 후 되돌릴 수 없습니다.")
        }
    }

    private var balanceRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("USDC 잔액").font(.caption).foregroundStyle(.secondary)
                if wallet.uiState.assetsLoading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6)
                        Text("조회 중…").font(.footnote)
                    }
                } else if let err = wallet.uiState.assetsError {
                    Text(err).font(.footnote).foregroundColor(.red)
                } else {
                    Text("\(balanceDisplay) USDC").font(.subheadline)
                }
                if krwLoading {
                    Text("환산 중…").font(.caption).foregroundStyle(.secondary)
                } else if let krw = krwText {
                    Text(krw).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("새로고침") { Task { await wallet.loadAssets() } }
                .font(.footnote)
                .disabled(wallet.uiState.assetsLoading)
        }
    }

    /// 공용 목록 갱신 시 USDC 잔액 기준 KRW 환산 (미보유면 "0" → ₩0).
    private func refreshKrw() async {
        krwGeneration += 1
        let gen = krwGeneration
        krwText = nil
        guard let usdcAddr = usdcAddress else { return }
        krwLoading = true
        let amt = usdc?.humanizedBalance ?? "0"
        let krw = await wallet.getKrwValue(chainId: chainId, contractAddress: usdcAddr, amount: amt)
        guard gen == krwGeneration else { return }
        krwText = krw
        krwLoading = false
    }
}
