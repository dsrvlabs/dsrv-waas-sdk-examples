import SwiftUI
import dsrv_wallet_sdk_ios

/// Android `PaymentSection.kt` 대응 — customer-backend `POST /payments` 호출 (cross-chain Topup).
///
/// source(출금) / destination(수령) 의 chain·token·주소를 직접 입력할 수 있다. 비우면 기본값으로
/// 폴백(source chain=선택 체인, fromAddress=내 지갑, fromTokenAddress=체인 USDC, destination=source 와 동일).
/// USDC 잔액/KRW 행은 선택 체인 기준 참고용 표시이며, 실제 결제 토큰은 fromTokenAddress 입력이 결정한다.
/// paymentType=0/sourceUserId 는 `Wallet.pay` 가 채움.
struct PaymentSection: View {
    @EnvironmentObject var wallet: Wallet

    @State private var to: String = ""
    @State private var amount: String = ""
    @State private var scannerOpen = false
    @State private var confirmOpen = false
    @State private var krwText: String? = nil
    @State private var krwLoading = false
    @State private var krwGeneration = 0
    // source(출금) / destination(수령) 입력 — 비우면 기본값 폴백(placeholder 로 기본값 노출).
    @State private var sourceChainText = ""
    @State private var fromTokenText = ""
    @State private var destChainText = ""
    @State private var destTokenText = ""

    private var chainId: String { wallet.uiState.selectedChainId ?? "" }

    // 입력값이 비면 사용할 기본값 (= 기존 자동 도출 동작). placeholder 와 확정 전송에 함께 쓴다.
    private var resolvedSourceChain: String { sourceChainText.isEmpty ? chainId : sourceChainText }
    // fromAddress 는 항상 현재 선택한 지갑 — 입력받지 않는다.
    private var resolvedFromAddress: String { wallet.address }
    private var resolvedFromToken: String {
        fromTokenText.isEmpty ? (PaymentSection.usdcAddress(chainId: resolvedSourceChain) ?? "") : fromTokenText
    }
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
        SectionCard("결제 (Topup)", subtitle: "source → destination · 체인 \(chain?.name ?? (chainId.isEmpty ? "없음" : chainId))") {
            // 잔액 helper (참고용) — 선택 체인의 USDC 잔액/KRW. 결제 토큰은 아래 fromTokenAddress 입력으로 결정.
            if usdcAddress != nil {
                balanceRow
            }

            // ── source (출금) ── chain 은 가져온 목록에서 선택, 나머지는 비우면 placeholder 의 기본값.
            // fromAddress 는 현재 선택한 지갑 고정 — 입력받지 않는다.
            groupCard {
                Text("source (출금)")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                chainField {
                    Picker("chain", selection: Binding(
                        get: { resolvedSourceChain },
                        set: { sourceChainText = $0 }
                    )) {
                        ForEach(wallet.uiState.chains, id: \.chainId) { c in
                            Text("\(c.name) (\(c.chainId))").tag(c.chainId)
                        }
                    }
                }
                TextField(
                    "fromTokenAddress (기본: \(PaymentSection.usdcAddress(chainId: resolvedSourceChain) ?? "0x…"))",
                    text: $fromTokenText
                )
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            }

            // ── destination (수령) ── chain/token 비우면 source 와 동일.
            groupCard {
                Text("destination (수령)")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    TextField("toAddress", text: $to)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    Button("QR 스캔") { scannerOpen = true }
                        .font(.footnote)
                }
                chainField {
                    Picker("chain", selection: $destChainText) {
                        Text("source 와 동일").tag("")
                        ForEach(wallet.uiState.chains, id: \.chainId) { c in
                            Text("\(c.name) (\(c.chainId))").tag(c.chainId)
                        }
                    }
                }
                TextField("tokenAddress (비우면 source 와 동일)", text: $destTokenText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            // ── 금액 ── destination 과 구분되는 별도 그룹.
            Text("금액")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("금액 (기본 1)", text: $amount)
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
        // 이미 목록이 로드된 채 진입하면 onChange(assets) 가 안 떠 KRW 가 비므로 appear 시에도 환산.
        .onAppear { Task { await wallet.loadAssets(); await refreshKrw() } }
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
                // amount 는 humanized 그대로 전송 — stablecoin Payments 가 decimals 변환 담당.
                // 빈 입력은 pay() / resolved* 기본값으로 폴백.
                let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : amount
                wallet.pay(
                    sourceChainIdInput: sourceChainText,
                    sourceTokenInput: resolvedFromToken,
                    fromInput: "",
                    destChainIdInput: destChainText,
                    destTokenInput: destTokenText,
                    toInput: to,
                    amountInput: effective
                )
            }
        } message: {
            let effective = amount.trimmingCharacters(in: .whitespaces).isEmpty ? "1" : amount
            let destChainDisplay = destChainText.isEmpty ? resolvedSourceChain : destChainText
            let destTokenDisplay = destTokenText.isEmpty ? resolvedFromToken : destTokenText
            return Text(
                "금액: \(effective)\n"
                    + "source: chain \(resolvedSourceChain) · \(resolvedFromAddress) · \(resolvedFromToken)\n"
                    + "dest: chain \(destChainDisplay) · \(to) · \(destTokenDisplay)\n\n"
                    + "⚠ 결제 후 되돌릴 수 없습니다."
            )
        }
    }

    /// source / destination 을 감싸는 옅은 카드 컨테이너.
    @ViewBuilder
    private func groupCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// "chain" 라벨 아래에 선택기를 세로로 배치 — source/destination 공통 레이아웃.
    @ViewBuilder
    private func chainField<Content: View>(@ViewBuilder _ picker: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("chain").font(.footnote).foregroundStyle(.secondary)
            picker()
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
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
